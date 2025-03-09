import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// IMPORTANT: Changed import to navigate to the workout session page.
import 'workout_session_page.dart';

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
    Query query = _firestore
        .collection('workouts')
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
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
              color: Color(0xFF1A1A2E),
              margin: EdgeInsets.all(8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: ListTile(
                title: Text(
                  workout['name'] ?? 'Unnamed Workout',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: Text(
                  DateFormat.yMMMd().format(
                    (workout['timestamp'] as Timestamp).toDate(),
                  ),
                  style: TextStyle(color: Colors.white70),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fitness_center, color: Colors.white),
                    SizedBox(width: 8),
                    Icon(
                      isFavorited ? Icons.star : Icons.star_border,
                      color: isFavorited ? Colors.amber : Colors.grey,
                    ),
                  ],
                ),
                onTap: () {
                  // Grab the old workout data as a template
                  final docData = doc.data() as Map<String, dynamic>;
                  // Remove fields that belong to the old doc
                  docData.remove('timestamp');
                  docData.remove('duration');
                  docData.remove('favorited');
                  // If there's an 'id' field or doc ID, remove it too
                  docData.remove('id');
                  // Also remove any leftover controllers/focusNodes so you don't reuse them
                  docData.remove('controllers');
                  docData.remove('focusNodes');

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutSessionPage(
                        preloadedWorkout: docData,
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
      backgroundColor: Color(0xFF000015),
      appBar: AppBar(
        backgroundColor: Color(0xFF000015),
        surfaceTintColor: Colors.transparent,
        title: Text('Favorite Workouts', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search field for favorite workouts
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search favorite workouts',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Color(0xFF000015),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
              style: TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildWorkoutList()),
        ],
      ),
    );
  }
}
