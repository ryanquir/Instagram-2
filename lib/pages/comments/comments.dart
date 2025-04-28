import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

class PostComments extends StatefulWidget {
  final String postId;
  const PostComments({required this.postId, super.key});


  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> {
  final TextEditingController _commentController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  final instagramDb = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'instagram2',
  );

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    await instagramDb
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'text': _commentController.text.trim(),
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: instagramDb
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    return ListTile(
                      title: Text(doc['text']),
                      subtitle: FutureBuilder<DocumentSnapshot>(
                        future: instagramDb.collection('users').doc(doc['userId']).get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text('Loading...');
                          final user = snapshot.data!.data() as Map<String, dynamic>;
                          return Text(user['email']);
                        },
                      ),
                    );
                  }).toList(),
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
                    controller: _commentController,
                    decoration: const InputDecoration(
                        hintText: 'Write a comment...'
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
