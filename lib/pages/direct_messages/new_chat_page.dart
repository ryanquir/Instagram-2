import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'package:firebase_core/firebase_core.dart';

class NewChatPage extends StatelessWidget {
  const NewChatPage({super.key});

  String getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Start New Chat')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'instagram2',
        ).collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: users.length,
            itemBuilder: (ctx, i) {
              final doc = users[i];
              if (doc.id == currentUser.uid) return const SizedBox();

              final data = doc.data()! as Map<String, dynamic>;
              final email = data['email'] as String? ?? 'User';
              final profileUrl = data['profileImageUrl'] as String? ?? '';

              Widget avatar;
              if (profileUrl.isNotEmpty) {
                avatar = ClipOval(
                  child: Image.network(
                    profileUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, prog) {
                      if (prog == null) return child;
                      return const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40),
                  ),
                );
              } else {
                avatar = const Icon(Icons.person, size: 40);
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: avatar,
                  title: Text(email, style: const TextStyle(fontSize: 16)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    final chatRoomId = getChatRoomId(currentUser.uid, doc.id);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          receiverId: doc.id,
                          receiverName: email,
                          chatRoomId: chatRoomId,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
