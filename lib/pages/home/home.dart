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
        'userEmail': email,
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
        if (snapshot.hasError) return const Center(child: Text("Error loading feed"));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;


        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(post['userEmail']),
                  if (post['imageUrl'] != null)
                    Image.network(post['imageUrl']),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      post['caption'] ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
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

                // 🔥 Replace CircleAvatar+spinner logic with this:
                StreamBuilder<DocumentSnapshot>(
                  stream: instagramDb
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      // still loading the doc
                      return const CircleAvatar(
                        radius: 50,
                        child: CircularProgressIndicator(),
                      );
                    }

                    // once not waiting, either we have data or an error
                    final doc = snap.data;
                    final url = (doc?.data() as Map<String, dynamic>?)
                    ?['profileImageUrl'] as String?;

                    return Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                          url != null ? NetworkImage(url) : null,
                          child: url == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        // edit button
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

          // ——— GRID OF POSTS (unchanged) ———
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
                if (!snap.hasData) {
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
                      onTap: () { /* your detail nav */ },
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