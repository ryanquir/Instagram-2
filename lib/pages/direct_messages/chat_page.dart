import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String chatRoomId;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.chatRoomId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  void sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final messageText = _controller.text.trim();
    final timestamp = FieldValue.serverTimestamp();

    final chatRoomDoc = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    ).collection('messages').doc(widget.chatRoomId);

    await chatRoomDoc.collection('chats').add({
      'senderId': currentUser.uid,
      'receiverId': widget.receiverId,
      'message': messageText,
      'timestamp': timestamp,
    });

    await chatRoomDoc.set({
      'userIds': [currentUser.uid, widget.receiverId],
      'lastMessage': messageText,
      'lastTimestamp': timestamp,
    }, SetOptions(merge: true));

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instanceFor(
                        app: Firebase.app(),
                        databaseId: 'instagram2',
                      )
                      .collection('messages')
                      .doc(widget.chatRoomId)
                      .collection('chats')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['senderId'] == currentUser.uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isMe
                                  ? Colors.deepPurple.shade300
                                  : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message['message'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
