import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'workout_session_page.dart';

class WorkoutHistoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> workout;
  final String workoutId; // Firestore doc ID for saving comments, etc.

  const WorkoutHistoryDetailPage({
    Key? key,
    required this.workout,
    required this.workoutId,
  }) : super(key: key);

  @override
  _WorkoutHistoryDetailPageState createState() =>
      _WorkoutHistoryDetailPageState();
}

class _WorkoutHistoryDetailPageState extends State<WorkoutHistoryDetailPage> {
  final TextEditingController _commentController = TextEditingController();

  // Local boolean to track if this workout is favorited
  bool isFavorited = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the comment text if it already exists in Firestore.
    _commentController.text = widget.workout['comments'] ?? '';
    // Load 'favorited' status from the workout map
    isFavorited = widget.workout['favorited'] == true;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Toggle the favorite status in Firestore
  Future<void> _toggleFavorite() async {
    setState(() {
      isFavorited = !isFavorited;
    });

    try {
      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .update({'favorited': isFavorited});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorited ? 'Added to favorites!' : 'Removed from favorites!',
          ),
        ),
      );
    } catch (e) {
      // If Firestore update fails, revert the local state
      setState(() {
        isFavorited = !isFavorited;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e')),
      );
    }
  }

  /// Calculate total volume across all strength exercises (only those where 'sets' is a List).
  int _calculateTotalVolume() {
    int totalVolume = 0;
    final exercises = widget.workout['exercises'] ?? [];
    for (var exercise in exercises) {
      if (exercise['sets'] is List) {
        for (var set in exercise['sets']) {
          final weight = (set['weight'] ?? 0) as num;
          final reps = (set['reps'] ?? 0) as num;
          totalVolume += (weight * reps).toInt();
        }
      }
    }
    return totalVolume;
  }

  Future<void> _saveComment() async {
    try {
      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .update({'comments': _commentController.text});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save comment: $e')),
      );
    }
  }

  /// Builds UI for a cardio exercise when data is stored as a nested Map in 'sets'.
  Widget _buildCardioFields(Map<String, dynamic> exercise) {
    final setsField = exercise['sets'];
    if (setsField is Map<String, dynamic>) {
      final duration = setsField['duration'];
      final miles = setsField['miles'];
      final reps = setsField['reps'];

      if (duration == null && miles == null && reps == null) {
        return Text("No cardio data logged");
      }

      return Row(
        children: [
          if (duration != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text("Duration: $duration"),
            ),
          if (miles != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text("Miles: $miles"),
            ),
          if (reps != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text("Reps: $reps"),
            ),
        ],
      );
    }
    return Text("No cardio data logged");
  }

  /// Builds UI for a strength exercise (where 'sets' is a List).
  /// Additionally, if a set has fields that look like cardio data (duration, miles, reps)
  /// and no weight, it will display that data.
  List<Widget> _buildStrengthSets(List setsList) {
    final widgets = <Widget>[];
    for (int i = 0; i < setsList.length; i++) {
      final setData = setsList[i] as Map<String, dynamic>;
      // Check if the set appears to have cardio data.
      if ((setData.containsKey('duration') ||
          setData.containsKey('miles') ||
          setData.containsKey('reps')) &&
          !setData.containsKey('weight')) {
        final duration = setData['duration'];
        final miles = setData['miles'];
        final reps = setData['reps'];
        final List<Widget> cardioWidgets = [];
        if (duration != null) {
          cardioWidgets.add(Text("Duration: $duration"));
        }
        if (miles != null) {
          cardioWidgets.add(Text("Miles: $miles"));
        }
        if (reps != null) {
          cardioWidgets.add(Text("Reps: $reps"));
        }
        widgets.add(Row(
          children: cardioWidgets
              .map((w) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: w,
          ))
              .toList(),
        ));
      } else {
        // Otherwise, treat as a strength set.
        final weight = setData['weight'];
        final reps = setData['reps'];
        if (weight == null && reps == null) continue;
        widgets.add(Text("Set ${i + 1}: Weight: $weight | Reps: $reps"));
      }
    }
    if (widgets.isEmpty) {
      widgets.add(Text("No sets data for this exercise"));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    // Convert Firestore timestamp to DateTime.
    DateTime workoutDate = DateTime.now();
    if (widget.workout['timestamp'] is Timestamp) {
      workoutDate = (widget.workout['timestamp'] as Timestamp).toDate();
    }

    final exercises = widget.workout['exercises'] ?? [];
    final totalVolume = _calculateTotalVolume();
    final workoutDescription = widget.workout['description'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout['name'] ?? 'Workout Details'),
        actions: [
          // Star icon in the AppBar to toggle favorite
          IconButton(
            icon: Icon(
              isFavorited ? Icons.star : Icons.star_border,
              color: isFavorited ? Colors.amber : Colors.grey,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Workout date
          Text(
            "Date: ${DateFormat.yMMMd().format(workoutDate)}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          // Optional description
          if (workoutDescription.isNotEmpty) ...[
            Text(
              "Description:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(workoutDescription),
            SizedBox(height: 16),
          ],
          // Total volume
          Text(
            "Total Volume Lifted: $totalVolume lbs",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 16),
          // Exercises section
          Text(
            "Exercises:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ...exercises.map<Widget>((exercise) {
            final exerciseName = exercise['name'] ?? 'Unnamed Exercise';
            final setsField = exercise['sets'];

            return Card(
              margin: EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise name
                    Text(
                      exerciseName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    // Cardio or strength sets display
                    if (setsField is Map<String, dynamic>)
                      _buildCardioFields(exercise),
                    if (setsField is List) ..._buildStrengthSets(setsField),
                    if (setsField == null)
                      Text("No data logged for this exercise"),
                  ],
                ),
              ),
            );
          }).toList(),
          // "Start this workout" button appears if this workout is favorited
          if (widget.workout['favorited'] == true) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to the workout session page with the current workout as a template.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutSessionPage(
                      preloadedWorkout: widget.workout,
                    ),
                  ),
                );
              },
              child: Text('Start this workout'),
            ),
          ],
          SizedBox(height: 24),
          // Comments section
          Text(
            "Comments:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Enter your comment',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saveComment,
            child: Text('Save Comment'),
          ),
        ],
      ),
    );
  }
}
