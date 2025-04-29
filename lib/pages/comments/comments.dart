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
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (text.length > 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Comments must be 60 characters or fewer."),
        ),
      );
      return;
    }
    await instagramDb
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
          'text': text,
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
              stream:
                  instagramDb
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
                  children:
                      snapshot.data!.docs.map((doc) {
                        return ListTile(
                          title: Text(doc['text']),
                          subtitle: FutureBuilder<DocumentSnapshot>(
                            future:
                                instagramDb
                                    .collection('users')
                                    .doc(doc['userId'])
                                    .get(),
                            builder: (context, snap2) {
                              if (!snap2.hasData)
                                return const Text('Loading...');
                              final userData =
                                  snap2.data!.data() as Map<String, dynamic>;
                              return Text(userData['email']);
                            },
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      counterText: '', // hides the default counter
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
