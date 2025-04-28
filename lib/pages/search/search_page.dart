import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:final_project/pages/home/home.dart';
//import 'package:final_project/pages/profile/profile.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'instagram2',
    );

    // pick the right stream: either the first 10 users or your filtered query
    final Stream<QuerySnapshot> userStream = _query.isEmpty
        ? db.collection('users').limit(10).snapshots()
        : db
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: _query)
        .where('email', isLessThanOrEqualTo: '$_query\uf8ff')
        .snapshots();

    return Column(
      children: [
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by email',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => setState(() => _query = val.trim()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: userStream,
            builder: (ctx, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snap.data!.docs;
              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.length,
                itemBuilder: (ctx, i) {
                  final userDoc = users[i];
                  final data    = userDoc.data() as Map<String, dynamic>;
                  final email   = data['email'] as String? ?? 'No email';
                  final uid     = data['userId'] as String? ?? userDoc.id;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(Icons.person),
                      title: Text(email, style: const TextStyle(fontSize: 16)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Profile(userId: uid),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
