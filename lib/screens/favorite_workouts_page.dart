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
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(
              "No favorite workouts found.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
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
              color: Theme.of(context).cardColor,
              margin: EdgeInsets.all(8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: ListTile(
                title: Text(
                  workout['name'] ?? 'Unnamed Workout',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  DateFormat.yMMMd().format(
                    (workout['timestamp'] as Timestamp).toDate(),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fitness_center, color: Theme.of(context).iconTheme.color),
                    SizedBox(width: 8),
                    Icon(
                      isFavorited ? Icons.star : Icons.star_border,
                      color: isFavorited ? Colors.amber : Theme.of(context).disabledColor,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Updated
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // Updated
        surfaceTintColor: Colors.transparent,
        title: Text('Favorite Workouts', style: Theme.of(context).appBarTheme.titleTextStyle), // Updated
      ),
      body: Column(
        children: [
          // Search field for favorite workouts
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search favorite workouts',
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor, // Updated
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor), // Updated
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildWorkoutList()),
        ],
      ),
    );
  }
}
