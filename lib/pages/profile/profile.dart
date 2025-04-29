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
import 'package:final_project/pages/home/home.dart';

class Profile extends StatelessWidget {
  final String userId;
  const Profile({Key? key, required this.userId}) : super(key: key);
  //AI Agent: ChatGPT
  //prompt: *pasted widget* add a circular progress indicator for when the profile pic is loading
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
          style: GoogleFonts.albertSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions:
            isMe
                ? [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => AuthService().signout(context: context),
                  ),
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
                  if (snap.connectionState == ConnectionState.waiting ||
                      !snap.hasData) {
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
                        errorBuilder:
                            (_, __, ___) => const SizedBox(
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
                        style: GoogleFonts.albertSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                stream:
                    db
                        .collection('posts')
                        .where('userId', isEqualTo: userId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final posts = snap.data!.docs;
                  if (posts.isEmpty)
                    return const Center(child: Text('No posts yet'));
                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                    itemCount: posts.length,
                    itemBuilder: (ctx, i) {
                      final doc = posts[i];
                      final img =
                          (doc.data()! as Map<String, dynamic>)['imageUrl']
                              as String?;
                      if (img == null) return const SizedBox();
                      return InkWell(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(post: doc),
                              ),
                            ),
                        child: Image.network(
                          img,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
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
              await ref.update({
                'following': FieldValue.arrayRemove([userId]),
              });
            } else {
              await ref.update({
                'following': FieldValue.arrayUnion([userId]),
              });
            }
          },
          child: Text(isFollowing ? 'Unfollow' : 'Follow'),
        );
      },
    );
  }
}
