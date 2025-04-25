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

class Home extends StatefulWidget {
  const Home({super.key});

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

    instagramDb = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    );
    _loadProfileImage();              // ← load at startup

    _screens.addAll([
      _buildFeedScreen(),
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

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
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
    return StreamBuilder<QuerySnapshot>(
      stream: instagramDb
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading feed"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post    = posts[index];
            final data    = post.data() as Map<String, dynamic>;
            final email   = (data['userEmail'] as String?) ?? 'Unknown user';
            final imageUrl= data['imageUrl'] as String?;
            final caption = data['caption'] as String? ?? '';
            final likes   = List<String>.from(data['likes'] ?? []);
            final current = FirebaseAuth.instance.currentUser!;
            final isLiked = likes.contains(current.uid);

            return Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clickable poster email
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Profile(userId: data['userId']),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: TextDecoration.underline, // optional: indicate link
                        ),
                      ),
                    ),
                  ),

                  // Post image
                  if (imageUrl != null)
                    Image.network(imageUrl),

                  // Caption
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      caption,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  // Like + comment row
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                        onPressed: () async {
                          final docRef = instagramDb.collection('posts').doc(post.id);
                          if (isLiked) {
                            await docRef.update({
                              'likes': FieldValue.arrayRemove([current.uid])
                            });
                          } else {
                            await docRef.update({
                              'likes': FieldValue.arrayUnion([current.uid])
                            });
                          }
                        },
                      ),
                      Text('${likes.length} likes'),
                      IconButton(
                        icon: const Icon(Icons.comment),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostComments(postId: post.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
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
        children: [
          if (_selectedImage != null)
            Image.file(_selectedImage!, height: 200),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo),
            label: const Text("Pick Image"),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            decoration: const InputDecoration(labelText: "Caption"),
          ),
          const SizedBox(height: 12),
          _isUploading
              ? const CircularProgressIndicator()
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Profile',
                  style: GoogleFonts.albertSans(
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                StreamBuilder<DocumentSnapshot>(
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
                    return Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: url != null ? NetworkImage(url) : null,
                          child: url == null ? const Icon(Icons.person, size: 50) : null,
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

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff964ddc),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        fixedSize: const Size(125, 60),
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

                const SizedBox(height: 10),

                Text(user.email ?? "No email",
                  style: GoogleFonts.albertSans(
                    textStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
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
                    final img = post['imageUrl'] as String?;
                    if (img == null) return const SizedBox();
                    return InkWell(
                      onTap: () {
                        // Navigate to detail screen, passing the full post doc
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ),
                        );
                      },
                      child: Image.network(img, fit: BoxFit.cover),
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
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Feed"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "Post"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class PostDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot post;
  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final data = post.data()! as Map<String, dynamic>;

    final imageUrl   = data['imageUrl']   as String?;
    final caption    = (data['caption']    as String?)?.trim() ?? '';
    final email      = (data['userEmail']  as String?) ?? 'Unknown';
    final timestampF = data['timestamp']   as Timestamp?;
    final dateText   = timestampF != null
    // e.g. “Apr 24, 2025 1:45 PM”
        ? DateFormat.yMMMd().add_jm().format(timestampF.toDate())
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Post Detail')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl, fit: BoxFit.cover),

            const SizedBox(height: 16),

            // — Caption
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                caption.isNotEmpty ? caption : 'No caption',
                style: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 8),

            // — Poster email
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'by $email',
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            // — Timestamp
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
          ],
        ),
      ),
    );
  }
}

class Profile extends StatelessWidget {
  final String userId;
  const Profile({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser != null && currentUser.uid == userId;
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.albertSans(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: isCurrentUser
            ? [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signout(context: context);
            },
          )
        ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile picture
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<DocumentSnapshot>(
                stream: db.collection('users').doc(userId).snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      radius: 50,
                      child: CircularProgressIndicator(),
                    );
                  }
                  final doc = snap.data;
                  final data = doc?.data() as Map<String, dynamic>?;
                  final url = data?['profileImageUrl'] as String?;
                  return CircleAvatar(
                    radius: 50,
                    backgroundImage: url != null ? NetworkImage(url) : null,
                    child: url == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  );
                },
              ),
            ),

            // Email
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<DocumentSnapshot>(
                future: db.collection('users').doc(userId).get(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }
                  final doc = snap.data;
                  final data = doc?.data() as Map<String, dynamic>?;
                  final email = data?['email'] as String? ?? 'No email';
                  return Text(
                    email,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.albertSans(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Posts grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('posts')
                    .where('userId', isEqualTo: userId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final posts = snap.data!.docs;
                  if (posts.isEmpty) {
                    return const Center(child: Text('No posts yet'));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (ctx, i) {
                      final post = posts[i];
                      final img = post['imageUrl'] as String?;
                      if (img == null) return const SizedBox();
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          );
                        },
                        child: Image.network(img, fit: BoxFit.cover),
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
}