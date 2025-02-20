import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'workout_session_page.dart';

class WorkoutHistoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> workout;
  final String workoutId;

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
  bool isFavorited = false;

  /// We store the duration as a friendly string, e.g. "35s", "2m 14s", "1h 5m 2s".
  String? workoutDurationString;

  @override
  void initState() {
    super.initState();
    _commentController.text = widget.workout['comments'] ?? '';
    isFavorited = widget.workout['favorited'] == true;

    // If your Firestore doc has a field "duration" in total seconds, parse it:
    final durationValue = widget.workout['duration'];
    if (durationValue != null) {
      final durationInSeconds = durationValue is int
          ? durationValue
          : int.tryParse(durationValue.toString()) ?? 0;

      // Convert total seconds to h/m/s
      final hours = durationInSeconds ~/ 3600;
      final minutes = (durationInSeconds % 3600) ~/ 60;
      final seconds = durationInSeconds % 60;

      // Build the friendly string
      final buffer = StringBuffer();
      if (hours > 0) buffer.write('${hours}h ');
      if (minutes > 0) buffer.write('${minutes}m ');
      if (seconds > 0) buffer.write('${seconds}s');

      // If somehow duration is 0, at least say "0s"
      workoutDurationString =
      buffer.isEmpty ? '0s' : buffer.toString().trim();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

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
      setState(() {
        isFavorited = !isFavorited;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e')),
      );
    }
  }

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
        widgets.add(
          Row(
            children: cardioWidgets
                .map((w) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: w,
            ))
                .toList(),
          ),
        );
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
          Text(
            "Date: ${DateFormat.yMMMd().format(workoutDate)}",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Show the duration string if present
          if (workoutDurationString != null)
            Text(
              "Duration: $workoutDurationString",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 8),

          if (workoutDescription.isNotEmpty) ...[
            Text(
              "Description:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(workoutDescription),
            const SizedBox(height: 16),
          ],

          Text(
            "Total Volume Lifted: $totalVolume lbs",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          Text(
            "Exercises:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...exercises.map<Widget>((exercise) {
            final exerciseName = exercise['name'] ?? 'Unnamed Exercise';
            final setsField = exercise['sets'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
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

          if (widget.workout['favorited'] == true) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
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

          const SizedBox(height: 24),
          Text(
            "Comments:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Enter your comment',
              border: OutlineInputBorder(),
            ),
            maxLines: null,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saveComment,
            child: Text('Save Comment'),
          ),
        ],
      ),
    );
  }
}
