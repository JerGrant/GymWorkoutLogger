import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class WorkoutSessionPage extends StatefulWidget {
  @override
  _WorkoutSessionPageState createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  Timer? _timer;
  int _duration = 0; // Duration in seconds
  String _workoutName = "Untitled Workout";
  String _workoutDescription = "";
  DocumentReference? _workoutRef;

  @override
  void initState() {
    super.initState();
    _startWorkout();
  }

  Future<void> _startWorkout() async {
    if (user == null) return;

    _workoutRef = await _firestore.collection('workouts').add({
      'userId': user!.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'duration': 0,
      'name': _workoutName,
      'description': _workoutDescription,
      'exercises': [],
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _duration++;
      });
    });
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();

    await _workoutRef?.update({
      'duration': _duration ~/ 60, // Convert to minutes
      'name': _workoutName,
      'description': _workoutDescription,
    });

    Navigator.pop(context);
  }

  Future<void> _cancelWorkout() async {
    _timer?.cancel();

    await _workoutRef?.delete();

    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "${minutes}m ${remainingSeconds}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout Session'),
        automaticallyImplyLeading: false, // Prevent accidental back navigation
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(labelText: 'Workout Name'),
              onChanged: (value) {
                setState(() {
                  _workoutName = value;
                });
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Description'),
              onChanged: (value) {
                setState(() {
                  _workoutDescription = value;
                });
              },
            ),
            SizedBox(height: 20),
            Text("Duration: ${_formatDuration(_duration)}", style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _cancelWorkout,
                  child: Text('Cancel Workout'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton(
                  onPressed: _finishWorkout,
                  child: Text('Finish Workout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
