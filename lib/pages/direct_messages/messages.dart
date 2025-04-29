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
        stream: FirebaseFirestore.instanceFor(
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

          // sort by most recent
          chatRooms.sort((a, b) {
            final tsA = a['lastTimestamp'] as Timestamp?;
            final tsB = b['lastTimestamp'] as Timestamp?;
            if (tsA == null || tsB == null) return 0;
            return tsB.compareTo(tsA);
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            itemCount: chatRooms.length,
            itemBuilder: (ctx, i) {
              final chatRoom = chatRooms[i];
              final userIds = List<String>.from(chatRoom['userIds']);
              final otherId = userIds.firstWhere(
                    (id) => id != currentUser.uid,
                orElse: () => '',
              );
              if (otherId.isEmpty) return const SizedBox();

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instanceFor(
                  app: Firebase.app(),
                  databaseId: 'instagram2',
                ).collection('users').doc(otherId).get(),
                builder: (ctx, userSnap) {
                  if (!userSnap.hasData) return const SizedBox();
                  final userData = userSnap.data!.data()! as Map<String, dynamic>;
                  final avatarUrl = userData['profileImageUrl'] as String? ?? '';
                  final username  = userData['email'] as String? ?? 'User';
                  final lastMsg   = chatRoom['lastMessage'] ?? '';

                  Widget leading = avatarUrl.isNotEmpty
                      ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, prog) {
                        if (prog == null) return child;
                        return const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 48),
                    ),
                  )
                      : const Icon(Icons.person, size: 48);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: leading,
                      title: Text(username, style: const TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        lastMsg,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              receiverId: otherId,
                              receiverName: username,
                              chatRoomId: chatRoom.id,
                            ),
                          ),
                        );
                      },
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
