import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_project/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:final_project/pages/comments/comments.dart';
import 'package:final_project/pages/profile/profile.dart';
import 'package:final_project/pages/search/search_page.dart';

class Home extends StatefulWidget {
  final int initialIndex;
  const Home({super.key, this.initialIndex = 0});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  final TextEditingController _captionController = TextEditingController();
  File? _selectedImage;
  bool _isUploading = false;
  late final FirebaseFirestore instagramDb;


  final List<Widget> _screens = [];
  String?  _profileImageUrl;
  bool    _isProfileLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    instagramDb = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    );
    _loadProfileImage();

    _screens.addAll([
      _buildFeedScreen(),
      const SearchPage(),
      _buildUploadPostScreen(),
      _buildProfileScreen(),
    ]);
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await instagramDb.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('profileImageUrl')) {
        _profileImageUrl = doc.data()!['profileImageUrl'] as String?;
      }
    }
    setState(() => _isProfileLoading = false);
  }

  Future<void> _pickAndUploadProfileImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploading = true);  // optional: show spinner

    final file = File(picked.path);
    final user = FirebaseAuth.instance.currentUser!;
    final ref  = FirebaseStorage.instance
        .ref()
        .child('profilePics/${user.uid}.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    // save URL to Firestore
    await instagramDb
        .collection('users')
        .doc(user.uid)
        .set({'profileImageUrl': url}, SetOptions(merge: true));

    setState(() {
      _profileImageUrl = url;
      _isUploading    = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadPost() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must pick an image before uploading."))
      );
      return;
    }
    // if (_captionController.text.trim().isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text("You must enter a caption before uploading."))
    //   );
    //   return;
    // }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email!;

      final ref = FirebaseStorage.instance
          .ref()
          .child('posts/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(_selectedImage!);
      final url = await ref.getDownloadURL();

      await instagramDb.collection('posts').add({
        'imageUrl': url,
        'caption': _captionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': email,          // ← save it here
        'likes': [],
      });

      // clear and go back to feed
      setState(() {
        _selectedImage = null;
        _captionController.clear();
        _selectedIndex = 0;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Post uploaded!")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }


  Widget _buildFeedScreen() {
    final current = FirebaseAuth.instance.currentUser!;
    final usersRef = instagramDb.collection('users');
    final postsRef = instagramDb.collection('posts');

    return FutureBuilder<DocumentSnapshot>(
      future: usersRef.doc(current.uid).get(),
      builder: (ctx, userSnap) {
        if (!userSnap.hasData || userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = userSnap.data!.data()! as Map<String, dynamic>;
        final following = List<String>.from(userData['following'] ?? []);
        // always include current user
        final userIds = {...following, current.uid}.toList();

        return StreamBuilder<QuerySnapshot>(
          stream: postsRef
              .where('userId', whereIn: userIds)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (ctx, postSnap) {
            if (postSnap.hasError) {
              return Center(child: Text('Error: ${postSnap.error}'));
            }
            if (!postSnap.hasData || postSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = postSnap.data!.docs;
            if (posts.isEmpty) {
              // no posts at all (including your own)
              return const Center(child: Text("Follow someone to see their posts!"));
            }

            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: posts.length,
                itemBuilder: (ctx, i) {
                  final doc   = posts[i];
                  final data  = doc.data()! as Map<String, dynamic>;
                  final email = data['userEmail'] as String? ?? '';
                  final img   = data['imageUrl']   as String?;
                  final cap   = data['caption']    as String? ?? '';
                  final likes = List<String>.from(data['likes'] ?? []);
                  final isLiked = likes.contains(current.uid);

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // — poster email
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Profile(userId: data['userId'] as String),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),

                        // — image with loading spinner
                        if (img != null)
                          Image.network(
                            img,
                            fit: BoxFit.cover,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(
                                height: 200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (_, __, ___) => const SizedBox(height: 200),
                          ),

                        // — like / comment row
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.grey,
                              ),
                              onPressed: () async {
                                final ref = postsRef.doc(doc.id);
                                if (isLiked) {
                                  await ref.update({
                                    'likes': FieldValue.arrayRemove([current.uid])
                                  });
                                } else {
                                  await ref.update({
                                    'likes': FieldValue.arrayUnion([current.uid])
                                  });
                                }
                              },
                            ),
                            Text('${likes.length} likes'),
                            IconButton(
                              icon: const Icon(Icons.comment),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostComments(postId: doc.id),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // — caption
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(cap, style: const TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }






  Widget _buildUploadPostScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 36),

          const SizedBox(height: 12),



          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Image.file(_selectedImage!, height: 250),
            )
          else SizedBox(height: 250),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(labelText: "Caption"),
              )
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text("Gallery"),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Camera"),
              ),
            ],
          ),
          const SizedBox(height: 12),


          _isUploading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
            onPressed: _uploadPost,
            child: const Text("Upload Post"),
          ),
        ],
      ),
    );
  }


  Widget _buildProfileScreen() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Not signed in"));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // — HEADER + PROFILE PICTURE —
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Profile',
                      style: GoogleFonts.albertSans(
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff964ddc),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        fixedSize: const Size(125, 48),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        await AuthService().signout(context: context);
                      },
                      child: const Text("Log Out"),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Profile picture centered
                Center(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: instagramDb.collection('users').doc(user.uid).snapshots(),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 50,
                          child: CircularProgressIndicator(),
                        );
                      }
                      final doc = snap.data;
                      if (doc == null || !doc.exists || doc.data() == null) {
                        return const CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.person, size: 50),
                        );
                      }
                      final data = doc.data()! as Map<String, dynamic>;
                      final url = data['profileImageUrl'] as String?;
                      if (url == null || url.isEmpty) {
                        return const CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.person, size: 50),
                        );
                      }
                      return Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            child: ClipOval(
                              child: Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _pickAndUploadProfileImage,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.edit, size: 16, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Email centered
                Center(
                  child: Text(
                    user.email ?? "No email",
                    style: GoogleFonts.albertSans(
                      textStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ——— GRID OF POSTS ———
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: instagramDb
                  .collection('posts')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error:\n${snap.error}'));
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snap.data!.docs;
                if (posts.isEmpty) {
                  return const Center(child: Text("No posts yet"));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (ctx, i) {
                    final post = posts[i];
                    final imgUrl = post['imageUrl'] as String?;
                    if (imgUrl == null) return const SizedBox();

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }












  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_selectedIndex) {
      case 0:
        body = _buildFeedScreen();
        break;
      case 1:
        body = const SearchPage();
        break;
      case 2:
        body = _buildUploadPostScreen();
        break;
      case 3:
        body = _buildProfileScreen();
        break;
      default:
        body = Container();
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Feed"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "Post"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final DocumentReference _postRef;
  late final String _currentUid;

  @override
  void initState() {
    super.initState();
    _postRef = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    ).collection('posts').doc(widget.post.id);
    _currentUid = FirebaseAuth.instance.currentUser!.uid;
  }

  void _toggleLike(List<dynamic> likes) async {
    if (likes.contains(_currentUid)) {
      await _postRef.update({
        'likes': FieldValue.arrayRemove([_currentUid]),
      });
    } else {
      await _postRef.update({
        'likes': FieldValue.arrayUnion([_currentUid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Detail')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _postRef.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData || snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data()! as Map<String, dynamic>;
          final imageUrl = data['imageUrl'] as String?;
          final caption  = (data['caption'] as String?)?.trim() ?? '';
          final email    = (data['userEmail'] as String?) ?? 'Unknown';
          final timestampF = data['timestamp'] as Timestamp?;
          final dateText = timestampF != null
              ? DateFormat.yMMMd().add_jm().format(timestampF.toDate())
              : '';
          final likes   = List<String>.from(data['likes'] ?? []);
          final isLiked = likes.contains(_currentUid);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, prog) {
                      if (prog == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),

                // — Likes row —
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _toggleLike(likes),
                      ),
                      Text('${likes.length} likes',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    caption.isNotEmpty ? caption : 'No caption',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('by $email', style: const TextStyle(color: Colors.grey)),
                ),

                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(dateText,
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],

                const SizedBox(height: 12),


              ],
            ),
          );
        },
      ),
    );
  }
}

class Profile extends StatelessWidget {
  final String userId;
  const Profile({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser!;
    final isMe = current.uid == userId;
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    );
    final usersRef = db.collection('users');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.albertSans(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: isMe
            ? [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signout(context: context),
          )
        ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // — PROFILE PICTURE & FOLLOW BUTTON —
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot>(
                stream: usersRef.doc(userId).snapshots(),
                builder: (ctx, snap) {
                  // loading state
                  if (snap.connectionState == ConnectionState.waiting || !snap.hasData) {
                    return const CircleAvatar(
                      radius: 50,
                      child: CircularProgressIndicator(),
                    );
                  }
                  final data = snap.data!.data()! as Map<String, dynamic>;
                  final url = data['profileImageUrl'] as String?;
                  final email = data['email'] as String? ?? '';

                  Widget avatar;
                  if (url != null && url.isNotEmpty) {
                    avatar = ClipOval(
                      child: Image.network(
                        url,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 100,
                            height: 100,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (_, __, ___) => const SizedBox(
                          width: 100,
                          height: 100,
                          child: Icon(Icons.person, size: 50),
                        ),
                      ),
                    );
                  } else {
                    avatar = const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    );
                  }

                  return Column(
                    children: [
                      avatar,
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: GoogleFonts.albertSans(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (!isMe) _buildFollowButton(context, usersRef),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
            // — POSTS GRID —
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('posts')
                    .where('userId', isEqualTo: userId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final posts = snap.data!.docs;
                  if (posts.isEmpty) return const Center(child: Text('No posts yet'));
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (ctx, i) {
                      final doc = posts[i];
                      final img = (doc.data()! as Map<String, dynamic>)['imageUrl'] as String?;
                      if (img == null) return const SizedBox();
                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PostDetailScreen(post: doc)),
                        ),
                        child: Image.network(
                          img,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(BuildContext ctx, CollectionReference usersRef) {
    final current = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<DocumentSnapshot>(
      stream: usersRef.doc(current.uid).snapshots(),
      builder: (c, meSnap) {
        if (!meSnap.hasData) return const SizedBox();
        final meData = meSnap.data!.data()! as Map<String, dynamic>;
        final following = List<String>.from(meData['following'] ?? []);
        final isFollowing = following.contains(userId);

        return ElevatedButton(
          onPressed: () async {
            final ref = usersRef.doc(current.uid);
            if (isFollowing) {
              await ref.update({'following': FieldValue.arrayRemove([userId])});
            } else {
              await ref.update({'following': FieldValue.arrayUnion([userId])});
            }
          },
          child: Text(isFollowing ? 'Unfollow' : 'Follow'),
        );
      },
    );
  }
}
