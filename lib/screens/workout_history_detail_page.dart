import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    // Pre-fill the comment text if it already exists in Firestore.
    _commentController.text = widget.workout['comments'] ?? '';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
    // Retrieve the workout-level description.
    final workoutDescription = widget.workout['description'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout['name'] ?? 'Workout Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Workout date.
          Text(
            "Date: ${DateFormat.yMMMd().format(workoutDate)}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          // Workout-level description.
          if (workoutDescription.isNotEmpty) ...[
            Text(
              "Description:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(workoutDescription),
            SizedBox(height: 16),
          ],
          // Total volume with "lbs".
          Text(
            "Total Volume Lifted: $totalVolume lbs",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 16),
          // Exercises.
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
                    // Exercise name.
                    Text(
                      exerciseName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    // If sets is a Map, assume it's a cardio exercise.
                    if (setsField is Map<String, dynamic>)
                      _buildCardioFields(exercise),
                    // If sets is a List, assume it's a strength exercise.
                    if (setsField is List)
                      ..._buildStrengthSets(setsField),
                    // Fallback.
                    if (setsField == null)
                      Text("No data logged for this exercise"),
                  ],
                ),
              ),
            );
          }).toList(),
          SizedBox(height: 24),
          // Comments section.
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
