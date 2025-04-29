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
import 'package:final_project/pages/direct_messages/messages.dart';

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
  String? _profileImageUrl;
  bool _isProfileLoading = true;

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

    setState(() => _isUploading = true);

    final file = File(picked.path);
    final user = FirebaseAuth.instance.currentUser!;
    final ref = FirebaseStorage.instance.ref().child(
      'profilePics/${user.uid}.jpg',
    );

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    // save URL to Firestore
    await instagramDb.collection('users').doc(user.uid).set({
      'profileImageUrl': url,
    }, SetOptions(merge: true));

    setState(() {
      _profileImageUrl = url;
      _isUploading = false;
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
        const SnackBar(
          content: Text("You must pick an image before uploading."),
        ),
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

      final ref = FirebaseStorage.instance.ref().child(
        'posts/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await ref.putFile(_selectedImage!);
      final url = await ref.getDownloadURL();

      await instagramDb.collection('posts').add({
        'imageUrl': url,
        'caption': _captionController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'userEmail': email,
        'likes': [],
      });

      // clear and go back to feed
      setState(() {
        _selectedImage = null;
        _captionController.clear();
        _selectedIndex = 0;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Post uploaded!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Widget _buildFeedScreen() {
    final current = FirebaseAuth.instance.currentUser!;
    final usersRef = instagramDb.collection('users');
    final postsRef = instagramDb.collection('posts');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Feed',
                  style: GoogleFonts.albertSans(
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    size: 28,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MessagesPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: usersRef.doc(current.uid).get(),
              builder: (ctx, userSnap) {
                if (!userSnap.hasData ||
                    userSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final following = List<String>.from(
                  (userSnap.data!.data()!
                          as Map<String, dynamic>)['following'] ??
                      [],
                );
                final userIds = {...following, current.uid}.toList();

                return StreamBuilder<QuerySnapshot>(
                  stream:
                      postsRef
                          .where('userId', whereIn: userIds)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                  builder: (ctx, postSnap) {
                    if (postSnap.hasError)
                      return Center(child: Text('Error: ${postSnap.error}'));
                    if (!postSnap.hasData ||
                        postSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final posts = postSnap.data!.docs;
                    if (posts.isEmpty) {
                      return const Center(
                        child: Text("Follow someone to see their posts!"),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (ctx, i) {
                          final doc = posts[i];
                          final data = doc.data()! as Map<String, dynamic>;
                          final email = data['userEmail'] as String? ?? '';
                          final img = data['imageUrl'] as String?;
                          final cap = data['caption'] as String? ?? '';
                          final ts = data['timestamp'] as Timestamp?;
                          final dateText =
                              ts != null
                                  ? DateFormat.yMMMd().add_jm().format(
                                    ts.toDate(),
                                  )
                                  : '';
                          final likes = List<String>.from(data['likes'] ?? []);
                          final isLiked = likes.contains(current.uid);

                          return Card(
                            margin: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // poster email
                                InkWell(
                                  onTap:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => Profile(
                                                userId:
                                                    data['userId'] as String,
                                              ),
                                        ),
                                      ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
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

                                // centered image at 80% width
                                if (img != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.35,
                                        width:
                                            MediaQuery.of(context).size.width *
                                            0.93,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            img,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (
                                              ctx,
                                              child,
                                              progress,
                                            ) {
                                              if (progress == null)
                                                return child;
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                            errorBuilder:
                                                (_, __, ___) => Container(
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // like/comment row
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color:
                                            isLiked ? Colors.red : Colors.grey,
                                      ),
                                      onPressed:
                                          () => postsRef.doc(doc.id).update({
                                            'likes':
                                                isLiked
                                                    ? FieldValue.arrayRemove([
                                                      current.uid,
                                                    ])
                                                    : FieldValue.arrayUnion([
                                                      current.uid,
                                                    ]),
                                          }),
                                    ),
                                    Text('${likes.length} likes'),
                                    const SizedBox(width: 16),
                                    FutureBuilder<QuerySnapshot>(
                                      future:
                                          postsRef
                                              .doc(doc.id)
                                              .collection('comments')
                                              .get(),
                                      builder: (ctx, snapCount) {
                                        final count =
                                            snapCount.hasData
                                                ? snapCount.data!.docs.length
                                                : 0;
                                        return InkWell(
                                          onTap:
                                              () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (_) => PostComments(
                                                        postId: doc.id,
                                                      ),
                                                ),
                                              ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.comment,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 4),
                                                Text('$count'),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                // caption
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '$email: $cap',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),

                                // date
                                if (dateText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      dateText,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadPostScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create Post',
                    style: GoogleFonts.albertSans(
                      textStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  _isUploading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : ElevatedButton(
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
                        onPressed: _uploadPost,
                        child: const Text("Upload"),
                      ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // — IMAGE PREVIEW / PLACEHOLDER —
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  height: 250,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        "Image preview",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            //const SizedBox(height: 12),
            if (_selectedImage == null)
              Text(
                textAlign: TextAlign.center,
                "Either choose an existing photo or take a new one",
              )
            else
              Text(
                textAlign: TextAlign.center,
                "You may select a new photo or retake it if you would like",
              ),
            const SizedBox(height: 12),

            // Getting a photo
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

            const SizedBox(height: 20),

            // CaptiOn Field
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Write a caption (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
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
          // Header and profile picture
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

                // Profile picture
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
                      final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                      final url  = data['profileImageUrl'] as String?;

                      return Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            child: ClipOval(
                              child: url != null && url.isNotEmpty
                                  ? Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, prog) {
                                  if (prog == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50),
                              )
                                  : const Icon(Icons.person, size: 50),
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

          // grid of posts
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
                    final post  = posts[i];
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

  void _toggleLike(List<dynamic> likes) {
    final liked = likes.contains(_currentUid);
    _postRef.update({
      'likes':
          liked
              ? FieldValue.arrayRemove([_currentUid])
              : FieldValue.arrayUnion([_currentUid]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('View Post')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _postRef.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData ||
              snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data()! as Map<String, dynamic>;
          final imageUrl = data['imageUrl'] as String?;
          final caption = (data['caption'] as String?)?.trim() ?? '';
          final email = (data['userEmail'] as String?) ?? 'Unknown';
          final timestamp = data['timestamp'] as Timestamp?;
          final dateText =
              timestamp != null
                  ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
                  : '';
          final likes = List<String>.from(data['likes'] ?? []);
          final isLiked = likes.contains(_currentUid);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: SizedBox(
                        height: screenH * 0.35,
                        width: screenW * 0.93,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, prog) {
                              if (prog == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // likes and comments
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
                      Text(
                        '${likes.length} likes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(width: 16),

                      FutureBuilder<QuerySnapshot>(
                        future: _postRef.collection('comments').get(),
                        builder: (ctx, snapCount) {
                          final count =
                              snapCount.hasData
                                  ? snapCount.data!.docs.length
                                  : 0;
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          PostComments(postId: widget.post.id),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.comment),
                                const SizedBox(width: 4),
                                Text('$count'),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // caption
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    caption.isNotEmpty
                        ? '$email: $caption'
                        : '$email: No caption',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),

                // timestamp
                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      dateText,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
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
