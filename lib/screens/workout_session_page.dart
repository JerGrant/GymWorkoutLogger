import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:gymworkoutlogger/screens/exercise_selection_modal.dart';

class WorkoutSessionPage extends StatefulWidget {
  @override
  _WorkoutSessionPageState createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  Timer? _timer;
  int _duration = 0;
  String _workoutName = "Untitled Workout";
  String _workoutDescription = "";
  DocumentReference? _workoutRef;
  List<Map<String, dynamic>> _selectedExercises = [];
  final ScrollController _scrollController = ScrollController();

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
      'duration': _duration ~/ 60,
      'name': _workoutName,
      'description': _workoutDescription,
      'exercises': _selectedExercises,
    });

    Navigator.pop(context);
  }

  Future<void> _cancelWorkout() async {
    _timer?.cancel();
    await _workoutRef?.delete();
    Navigator.pop(context);
  }

  void _openExerciseSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ExerciseSelectionModal(
          alreadySelectedExercises: _selectedExercises,
          onExercisesSelected: (selected) {
            setState(() {
              for (var exercise in selected) {
                exercise['sets'] = exercise['sets'] ?? [];
                _selectedExercises.add(exercise);
              }
            });
          },
        ),
      ),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      _selectedExercises.removeAt(index);
    });
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      if (_selectedExercises[exerciseIndex]['sets'] == null) {
        _selectedExercises[exerciseIndex]['sets'] = [];
      }
      _selectedExercises[exerciseIndex]['sets'].add({'reps': 0, 'weight': 0.0});
    });
    Future.delayed(Duration(milliseconds: 200), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'].removeAt(setIndex);
    });
  }

  void _updateReps(int exerciseIndex, int setIndex, int reps) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['reps'] = reps;
    });
  }

  void _updateWeight(int exerciseIndex, int setIndex, double weight) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['weight'] = weight;
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m ${remainingSeconds}s";
    }

    return "${minutes}m ${remainingSeconds}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Workout Session'),
            Text(
              "Duration: ${_formatDuration(_duration)}",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
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
            ElevatedButton(
              onPressed: _openExerciseSelection,
              child: Text('Add Exercise'),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _selectedExercises.length,
                itemBuilder: (context, exerciseIndex) {
                  var exercise = _selectedExercises[exerciseIndex];

                  if (exercise['sets'] == null) {
                    exercise['sets'] = [];
                  }

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise['name'] ?? 'Unnamed Exercise',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "${exercise['category'] ?? 'Unknown Category'} | ${exercise['bodyPart'] ?? 'Unknown Body Part'}${exercise['subcategory'] != null ? ' (${exercise['subcategory']})' : ''}",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.add, color: Colors.green),
                                    onPressed: () => _addSet(exerciseIndex),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeExercise(exerciseIndex),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            children: List.generate(exercise['sets'].length, (setIndex) {
                              var set = exercise['sets'][setIndex];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Set ${setIndex + 1}"),
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        child: TextField(
                                          decoration: InputDecoration(labelText: "Reps"),
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            _updateReps(exerciseIndex, setIndex, int.tryParse(value) ?? 0);
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Container(
                                        width: 70,
                                        child: TextField(
                                          decoration: InputDecoration(labelText: "Weight (lbs)"),
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (value) {
                                            _updateWeight(exerciseIndex, setIndex, double.tryParse(value) ?? 0.0);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.add, color: Colors.green),
                                        onPressed: () => _addSet(exerciseIndex),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.remove, color: Colors.red),
                                        onPressed: () => _removeSet(exerciseIndex, setIndex),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Swapped button positions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Finish Workout button is now on the left
                ElevatedButton(
                  onPressed: _finishWorkout,
                  child: Text('Finish Workout'),
                ),
                // Cancel Workout button is now on the right
                ElevatedButton(
                  onPressed: _cancelWorkout,
                  child: Text('Cancel Workout'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
