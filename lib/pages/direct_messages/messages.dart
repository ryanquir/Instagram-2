import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'new_chat_page.dart';
import 'package:firebase_core/firebase_core.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewChatPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instanceFor(
                  app: Firebase.app(),
                  databaseId: 'instagram2',
                )
                .collection('messages')
                .where('userIds', arrayContains: currentUser.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final chatRooms = snapshot.data!.docs;

          if (chatRooms.isEmpty) {
            return const Center(child: Text('No conversations yet'));
          }
          chatRooms.sort((a, b) {
            final tsA = a['lastTimestamp'] as Timestamp?;
            final tsB = b['lastTimestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA);
          });

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              final userIds = List<String>.from(chatRoom['userIds']);
              final otherUserId = userIds.firstWhere(
                (id) => id != currentUser.uid,
                orElse: () => '',
              );

              if (otherUserId.isEmpty) return const SizedBox();

              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instanceFor(
                      app: Firebase.app(),
                      databaseId: 'instagram2',
                    ).collection('users').doc(otherUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const SizedBox();
                  }
                  final user = userSnap.data!;
                  final username = user['email'] ?? 'User';
                  final lastMessage = chatRoom['lastMessage'] ?? '';

                  return ListTile(
                    title: Text(username),
                    subtitle: Text(
                      lastMessage,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatPage(
                                receiverId: otherUserId,
                                receiverName: username,
                                chatRoomId: chatRoom.id,
                              ),
                        ),
                      );
                    },
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
