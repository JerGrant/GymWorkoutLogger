import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'workout_history_detail_page.dart';

class FavoriteWorkoutsPage extends StatefulWidget {
  @override
  _FavoriteWorkoutsPageState createState() => _FavoriteWorkoutsPageState();
}

class _FavoriteWorkoutsPageState extends State<FavoriteWorkoutsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  String searchQuery = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  Stream<QuerySnapshot> getFavoriteWorkouts() {
    Query query = _firestore.collection('workouts')
        .where('userId', isEqualTo: user?.uid)
        .where('favorited', isEqualTo: true)
        .orderBy('timestamp', descending: true);

    if (searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _capitalize(searchQuery))
          .where('name', isLessThanOrEqualTo: _capitalize(searchQuery) + '\uf8ff');
    }

    return query.snapshots();
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = value.trim();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildWorkoutList() {
    return StreamBuilder<QuerySnapshot>(
      stream: getFavoriteWorkouts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No favorite workouts found.",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final workout = doc.data() as Map<String, dynamic>;
            final workoutId = doc.id;
            final isFavorited = workout['favorited'] == true;

            return Card(
              margin: EdgeInsets.all(8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: ListTile(
                title: Text(
                  workout['name'] ?? 'Unnamed Workout',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  DateFormat.yMMMd().format(
                    (workout['timestamp'] as Timestamp).toDate(),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fitness_center),
                    SizedBox(width: 8),
                    Icon(
                      isFavorited ? Icons.star : Icons.star_border,
                      color: isFavorited ? Colors.amber : Colors.grey,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutHistoryDetailPage(
                        workout: workout,
                        workoutId: workoutId,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Workouts'),
      ),
      body: Column(
        children: [
          // Optional search field for favorite workouts
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search favorite workouts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildWorkoutList()),
        ],
      ),
    );
  }
}
