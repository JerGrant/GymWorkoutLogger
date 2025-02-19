import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:gymworkoutlogger/screens/exercise_selection_modal.dart';

class WorkoutSessionPage extends StatefulWidget {
  // Optional parameter to preload workout data from a favorited workout.
  final Map<String, dynamic>? preloadedWorkout;

  const WorkoutSessionPage({Key? key, this.preloadedWorkout}) : super(key: key);

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
    if (widget.preloadedWorkout != null) {
      _workoutName = widget.preloadedWorkout!['name'] ?? "Untitled Workout";
      _workoutDescription = widget.preloadedWorkout!['description'] ?? "";
      _selectedExercises = widget.preloadedWorkout!['exercises'] != null
          ? List<Map<String, dynamic>>.from(widget.preloadedWorkout!['exercises'])
          : [];
    }
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
      'exercises': _selectedExercises,
    });

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration++;
        });
        print("Timer running: $_duration seconds");
      } else {
        _timer?.cancel();
      }
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

  /// Helper function that converts specified fields to String if needed.
  Map<String, dynamic> convertExerciseFields(Map<String, dynamic> exercise) {
    // Fields expected to be Strings.
    List<String> fields = ['name', 'category', 'bodyPart', 'subcategory'];
    Map<String, dynamic> newExercise = Map.from(exercise);
    for (var field in fields) {
      if (newExercise.containsKey(field)) {
        if (newExercise[field] is List) {
          newExercise[field] =
              (newExercise[field] as List).map((e) => e.toString()).join(', ');
        } else if (newExercise[field] == null) {
          newExercise[field] = '';
        }
      } else {
        newExercise[field] = '';
      }
    }
    // Ensure 'sets' is a list.
    if (!(newExercise['sets'] is List)) {
      newExercise['sets'] = [];
    }
    return newExercise;
  }

  void _openExerciseSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ExerciseSelectionModal(
          onExercisesSelected: (selected) {
            setState(() {
              for (var exercise in selected) {
                // Convert the exercise fields.
                Map<String, dynamic> fixedExercise = convertExerciseFields(exercise);
                // Ensure we include the exercise id for fetching history later.
                fixedExercise['id'] = exercise['id'];
                _selectedExercises.add(fixedExercise);
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

  /// Helper to determine default set fields based on category.
  Map<String, dynamic> _getDefaultSet(String category) {
    final lower = category.toLowerCase();
    if (lower.contains("cardio")) {
      return {'miles': 0.0, 'duration': 0};
    } else if (lower.contains("lap")) {
      return {'reps': 0, 'duration': 0};
    } else if (lower.contains("isometric")) {
      return {'reps': 0, 'weight': 0.0, 'duration': 0};
    } else if (lower.contains("stretching") ||
        lower.contains("mobility") ||
        lower == "duration") {
      return {'duration': 0};
    } else if (lower.contains("assisted body")) {
      return {'reps': 0, 'weight': 0.0};
    } else if (lower.contains("non-weight")) {
      return {'reps': 0};
    } else {
      return {'reps': 0, 'weight': 0.0};
    }
  }

  void _addSet(int exerciseIndex) {
    final exercise = _selectedExercises[exerciseIndex];
    final category = exercise['category']?.toString() ?? "";
    final newSet = _getDefaultSet(category);

    setState(() {
      if (exercise['sets'] == null) {
        exercise['sets'] = [];
      }
      exercise['sets'].add(newSet);
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

  void _updateDuration(int exerciseIndex, int setIndex, int duration) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['duration'] = duration;
    });
  }

  void _updateMiles(int exerciseIndex, int setIndex, double miles) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['miles'] = miles;
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

  /// (Updated) Fetch ALL occurrences for the exercise, find best entry, and then last 10.
  Future<Map<String, dynamic>> _fetchExerciseHistory(String exerciseId) async {
    List<Map<String, dynamic>> allEntries = [];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {'bestEntry': null, 'recent': []};

    final workoutsSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .get();

    double maxVolume = 0.0;
    Map<String, dynamic>? bestEntry;

    for (var doc in workoutsSnapshot.docs) {
      Timestamp? ts = doc['timestamp'];
      DateTime workoutDate = ts != null ? ts.toDate() : DateTime.now();
      List exercises = doc['exercises'] ?? [];

      for (var ex in exercises) {
        if (ex['id'] == exerciseId) {
          double volume = 0.0;
          List sets = ex['sets'] ?? [];
          for (var set in sets) {
            if (set.containsKey('weight') && set.containsKey('reps')) {
              double weight = 0.0;
              int reps = 0;
              if (set['weight'] is int) {
                weight = (set['weight'] as int).toDouble();
              } else if (set['weight'] is double) {
                weight = set['weight'];
              }
              if (set['reps'] is int) {
                reps = set['reps'];
              } else {
                reps = int.tryParse(set['reps'].toString()) ?? 0;
              }
              volume += weight * reps;
            }
          }
          final entry = {
            'date': workoutDate,
            'volume': volume,
            'sets': sets,
          };
          allEntries.add(entry);

          // Track best volume
          if (volume > maxVolume) {
            maxVolume = volume;
            bestEntry = entry;
          }
        }
      }
    }

    // Sort by date descending
    allEntries.sort((a, b) => b['date'].compareTo(a['date']));

    // Remove bestEntry from the list so it's not duplicated
    if (bestEntry != null) {
      allEntries.remove(bestEntry);
    }

    // The "recent" list is the next 10 entries
    final recent = allEntries.take(10).toList();

    return {
      'bestEntry': bestEntry,
      'recent': recent,
    };
  }

  /// Show a dialog with the personal best (if any) at the top, then last 10.
  void _showExerciseHistoryForExercise(Map<String, dynamic> exercise) async {
    final exerciseId = exercise['id'];
    if (exerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exercise ID not available.")),
      );
      return;
    }

    final data = await _fetchExerciseHistory(exerciseId);
    final bestEntry = data['bestEntry'] as Map<String, dynamic>?;
    final recent = data['recent'] as List<Map<String, dynamic>>;

    if (bestEntry == null && recent.isEmpty) {
      // No data at all
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Exercise History for ${exercise['name']}"),
          content: Text("No history found for this exercise."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            )
          ],
        ),
      );
      return;
    }

    // Build the dialog content
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Exercise History for ${exercise['name']}"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Best
                if (bestEntry != null) ...[
                  Text("Personal Best",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _buildHistoryCard(bestEntry, showTrophy: true),
                  SizedBox(height: 20),
                ],
                // Recent
                Text("Recent History",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (recent.isEmpty)
                  Text("No recent entries.")
                else
                  for (var entry in recent)
                    _buildHistoryCard(entry, showTrophy: false),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            )
          ],
        );
      },
    );
  }

  /// Builds a small card-like widget for an entry, showing date, volume, and sets.
  Widget _buildHistoryCard(Map<String, dynamic> entry, {bool showTrophy = false}) {
    DateTime date = entry['date'];
    double volume = entry['volume'] ?? 0.0;
    List sets = entry['sets'] ?? [];

    // Build sets text
    String setDetails = sets.asMap().entries.map((e) {
      int setNum = e.key + 1;
      var set = e.value;
      var weight = set.containsKey('weight') ? set['weight'] : '-';
      var reps = set.containsKey('reps') ? set['reps'] : '-';
      return "Set $setNum: ${weight}lbs x ${reps} reps";
    }).join("\n");

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: showTrophy ? Icon(Icons.emoji_events, color: Colors.amber) : null,
        title: Text("${date.toLocal().toString().split('.')[0]}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Volume: ${volume.toStringAsFixed(1)}"),
            Text(setDetails),
          ],
        ),
      ),
    );
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
              controller: TextEditingController(text: _workoutName),
              onChanged: (value) {
                setState(() {
                  _workoutName = value;
                });
              },
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Description'),
              controller: TextEditingController(text: _workoutDescription),
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

                  return InkWell(
                    onTap: () => _showExerciseHistoryForExercise(exercise),
                    child: Card(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Exercise header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exercise['name'] ?? 'Unnamed Exercise',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
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
                            // Sets
                            Column(
                              children: List.generate(exercise['sets'].length, (setIndex) {
                                var set = exercise['sets'][setIndex];
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Set ${setIndex + 1}"),
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (set.containsKey('reps'))
                                            Container(
                                              width: 50,
                                              child: TextField(
                                                decoration:
                                                InputDecoration(labelText: "Reps"),
                                                keyboardType: TextInputType.number,
                                                onChanged: (value) {
                                                  _updateReps(
                                                      exerciseIndex,
                                                      setIndex,
                                                      int.tryParse(value) ?? 0);
                                                },
                                              ),
                                            ),
                                          if (set.containsKey('weight'))
                                            Container(
                                              width: 70,
                                              child: TextField(
                                                decoration: InputDecoration(
                                                    labelText: "Weight (lbs)"),
                                                keyboardType:
                                                TextInputType.numberWithOptions(
                                                    decimal: true),
                                                onChanged: (value) {
                                                  _updateWeight(
                                                      exerciseIndex,
                                                      setIndex,
                                                      double.tryParse(value) ?? 0.0);
                                                },
                                              ),
                                            ),
                                          if (set.containsKey('duration'))
                                            Container(
                                              width: 70,
                                              child: TextField(
                                                decoration: InputDecoration(
                                                    labelText: "Duration (sec)"),
                                                keyboardType: TextInputType.number,
                                                onChanged: (value) {
                                                  _updateDuration(
                                                      exerciseIndex,
                                                      setIndex,
                                                      int.tryParse(value) ?? 0);
                                                },
                                              ),
                                            ),
                                          if (set.containsKey('miles'))
                                            Container(
                                              width: 70,
                                              child: TextField(
                                                decoration:
                                                InputDecoration(labelText: "Miles"),
                                                keyboardType:
                                                TextInputType.numberWithOptions(
                                                    decimal: true),
                                                onChanged: (value) {
                                                  _updateMiles(
                                                      exerciseIndex,
                                                      setIndex,
                                                      double.tryParse(value) ?? 0.0);
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.add, color: Colors.green),
                                          onPressed: () => _addSet(exerciseIndex),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.remove, color: Colors.red),
                                          onPressed: () =>
                                              _removeSet(exerciseIndex, setIndex),
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
                    ),
                  );
                },
              ),
            ),
            // Finish/Cancel buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _finishWorkout,
                  child: Text('Finish Workout'),
                ),
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
