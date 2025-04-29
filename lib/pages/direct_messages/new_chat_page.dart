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
        stream:
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: 'instagram2',
            ).collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              if (user.id == currentUser.uid) return const SizedBox();
              return ListTile(
                title: Text(user['email'] ?? 'User'),
                onTap: () {
                  final chatRoomId = getChatRoomId(currentUser.uid, user.id);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ChatPage(
                            receiverId: user.id,
                            receiverName: user['email'] ?? 'User',
                            chatRoomId: chatRoomId,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
