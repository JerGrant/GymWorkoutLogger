import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:gymworkoutlogger/screens/exercise_selection_modal.dart';

class WorkoutSessionPage extends StatefulWidget {
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

  final TextEditingController _workoutNameController = TextEditingController();
  final TextEditingController _workoutDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.preloadedWorkout != null) {
      _workoutName = widget.preloadedWorkout!['name'] ?? "Untitled Workout";
      _workoutDescription = widget.preloadedWorkout!['description'] ?? "";
      _selectedExercises = widget.preloadedWorkout!['exercises'] != null
          ? List<Map<String, dynamic>>.from(widget.preloadedWorkout!['exercises'])
          : [];
      for (var exercise in _selectedExercises) {
        exercise['controllers'] ??= [];
        exercise['focusNodes'] ??= [];
        for (var i = 0; i < (exercise['sets']?.length ?? 0); i++) {
          Map<String, TextEditingController> ctrl = {};
          Map<String, FocusNode> nodes = {};
          if (exercise['sets'][i].containsKey('reps')) {
            final repsVal = exercise['sets'][i]['reps'];
            ctrl['reps'] = TextEditingController(
              text: (repsVal == null || repsVal == 0) ? "" : repsVal.toString(),
            );
            nodes['reps'] = FocusNode();
            nodes['reps']!.addListener(() {
              if (!nodes['reps']!.hasFocus) {
                _verifyAndUpdateReps(
                  _selectedExercises.indexOf(exercise),
                  i,
                  ctrl['reps']!.text,
                );
              }
            });
          }
          if (exercise['sets'][i].containsKey('weight')) {
            final weightVal = exercise['sets'][i]['weight'];
            ctrl['weight'] = TextEditingController(
              text: (weightVal == null || weightVal == 0.0) ? "" : weightVal.toString(),
            );
            nodes['weight'] = FocusNode();
            nodes['weight']!.addListener(() {
              if (!nodes['weight']!.hasFocus) {
                _verifyAndUpdateWeight(
                  _selectedExercises.indexOf(exercise),
                  i,
                  ctrl['weight']!.text,
                );
              }
            });
          }
          exercise['controllers'].add(ctrl);
          exercise['focusNodes'].add(nodes);
        }
      }
    }
    _workoutNameController.text = _workoutName;
    _workoutDescriptionController.text = _workoutDescription;
    _workoutNameController.addListener(() {
      setState(() {
        _workoutName = _workoutNameController.text;
      });
    });
    _workoutDescriptionController.addListener(() {
      setState(() {
        _workoutDescription = _workoutDescriptionController.text;
      });
    });

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
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _finishWorkout() async {
    _timer?.cancel();

    // Clean up _selectedExercises by removing non-serializable keys.
    List<Map<String, dynamic>> cleanedExercises = _selectedExercises.map((exercise) {
      var cleaned = Map<String, dynamic>.from(exercise);
      cleaned.remove("controllers");
      cleaned.remove("focusNodes");
      return cleaned;
    }).toList();

    await _workoutRef?.update({
      'duration': _duration ~/ 60,
      'name': _workoutName,
      'description': _workoutDescription,
      'exercises': cleanedExercises,
    });
    Navigator.pop(context);
  }

  Future<void> _cancelWorkout() async {
    _timer?.cancel();
    await _workoutRef?.delete();
    Navigator.pop(context);
  }

  Map<String, dynamic> convertExerciseFields(Map<String, dynamic> exercise) {
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
                Map<String, dynamic> fixedExercise = convertExerciseFields(exercise);
                fixedExercise['id'] = exercise['id'];
                fixedExercise['controllers'] = <Map<String, TextEditingController>>[];
                fixedExercise['focusNodes'] = <Map<String, FocusNode>>[];
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
      for (var map in _selectedExercises[index]['controllers']) {
        map.values.forEach((c) => c.dispose());
      }
      for (var map in _selectedExercises[index]['focusNodes']) {
        map.values.forEach((node) => node.dispose());
      }
      _selectedExercises.removeAt(index);
    });
  }

  Map<String, dynamic> _getDefaultSet(String category) {
    final lower = category.toLowerCase();
    if (lower.contains("cardio")) {
      return {'miles': null, 'duration': null};
    } else if (lower.contains("lap")) {
      return {'reps': null, 'duration': null};
    } else if (lower.contains("isometric")) {
      return {'reps': null, 'weight': null, 'duration': null};
    } else if (lower.contains("stretching") ||
        lower.contains("mobility") ||
        lower == "duration") {
      return {'duration': null};
    } else if (lower.contains("assisted body")) {
      return {'reps': null, 'weight': null};
    } else if (lower.contains("non-weight")) {
      return {'reps': null};
    } else {
      return {'reps': null, 'weight': null};
    }
  }

  void _addSet(int exerciseIndex) {
    final exercise = _selectedExercises[exerciseIndex];
    final category = exercise['category']?.toString() ?? "";
    final newSet = _getDefaultSet(category);
    Map<String, TextEditingController> newControllers = {};
    Map<String, FocusNode> newFocusNodes = {};

    if (newSet.containsKey('reps')) {
      newControllers['reps'] = TextEditingController(text: "");
      newFocusNodes['reps'] = FocusNode();
      newFocusNodes['reps']!.addListener(() {
        if (!newFocusNodes['reps']!.hasFocus) {
          _verifyAndUpdateReps(
            exerciseIndex,
            exercise['sets'].length,
            newControllers['reps']!.text,
          );
        }
      });
    }
    if (newSet.containsKey('weight')) {
      newControllers['weight'] = TextEditingController(text: "");
      newFocusNodes['weight'] = FocusNode();
      newFocusNodes['weight']!.addListener(() {
        if (!newFocusNodes['weight']!.hasFocus) {
          _verifyAndUpdateWeight(
            exerciseIndex,
            exercise['sets'].length,
            newControllers['weight']!.text,
          );
        }
      });
    }
    setState(() {
      exercise['sets'].add(newSet);
      exercise['controllers'] ??= <Map<String, TextEditingController>>[];
      exercise['focusNodes'] ??= <Map<String, FocusNode>>[];
      exercise['controllers'].add(newControllers);
      exercise['focusNodes'].add(newFocusNodes);
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
      Map<String, TextEditingController> ctrls =
      _selectedExercises[exerciseIndex]['controllers'][setIndex];
      ctrls.values.forEach((c) => c.dispose());
      Map<String, FocusNode> nodes =
      _selectedExercises[exerciseIndex]['focusNodes'][setIndex];
      nodes.values.forEach((n) => n.dispose());
      _selectedExercises[exerciseIndex]['sets'].removeAt(setIndex);
      _selectedExercises[exerciseIndex]['controllers'].removeAt(setIndex);
      _selectedExercises[exerciseIndex]['focusNodes'].removeAt(setIndex);
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
          if (volume > maxVolume) {
            maxVolume = volume;
            bestEntry = entry;
          }
        }
      }
    }

    allEntries.sort((a, b) => b['date'].compareTo(a['date']));
    if (bestEntry != null) {
      allEntries.remove(bestEntry);
    }
    final recent = allEntries.take(10).toList();

    return {
      'bestEntry': bestEntry,
      'recent': recent,
    };
  }

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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Exercise History for ${exercise['name']}"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bestEntry != null) ...[
                  Text("Personal Best",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _buildHistoryCard(bestEntry, showTrophy: true),
                  SizedBox(height: 20),
                ],
                Text("Recent History",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (recent.isEmpty)
                  Text("No recent entries.")
                else
                  for (var entry in recent) _buildHistoryCard(entry, showTrophy: false),
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

  Widget _buildHistoryCard(Map<String, dynamic> entry, {bool showTrophy = false}) {
    DateTime date = entry['date'];
    double volume = entry['volume'] ?? 0.0;
    List sets = entry['sets'] ?? [];
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

  Future<bool> _showVerificationDialog(String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Value"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Yes"),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _verifyAndUpdateReps(
      int exerciseIndex, int setIndex, String valueStr) async {
    int reps = int.tryParse(valueStr) ?? 0;
    if (reps > 100) {
      bool confirmed =
      await _showVerificationDialog("You entered over 100 reps. Are you sure?");
      if (!confirmed) {
        setState(() {
          _selectedExercises[exerciseIndex]['sets'][setIndex]['reps'] = null;
          _selectedExercises[exerciseIndex]['controllers'][setIndex]['reps']?.text = "";
        });
        return;
      }
    }
    _updateReps(exerciseIndex, setIndex, reps);
  }

  Future<void> _verifyAndUpdateWeight(
      int exerciseIndex, int setIndex, String valueStr) async {
    double weight = double.tryParse(valueStr) ?? 0.0;
    if (weight > 500) {
      bool confirmed = await _showVerificationDialog("You entered over 500 lbs. Are you sure?");
      if (!confirmed) {
        setState(() {
          _selectedExercises[exerciseIndex]['sets'][setIndex]['weight'] = null;
          _selectedExercises[exerciseIndex]['controllers'][setIndex]['weight']?.text = "";
        });
        return;
      }
    }
    _updateWeight(exerciseIndex, setIndex, weight);
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
              controller: _workoutNameController,
            ),
            TextField(
              decoration: InputDecoration(labelText: 'Description'),
              controller: _workoutDescriptionController,
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
                  exercise['sets'] ??= [];
                  exercise['controllers'] ??= [];
                  exercise['focusNodes'] ??= [];
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
                              Expanded(
                                child: Column(
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
                              ),
                              IconButton(
                                icon: Icon(Icons.info_outline, color: Colors.blue),
                                onPressed: () {
                                  _showExerciseHistoryForExercise(exercise);
                                },
                              ),
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
                          Column(
                            children: List.generate(exercise['sets'].length, (setIndex) {
                              var set = exercise['sets'][setIndex];
                              Map<String, TextEditingController> controllers =
                              exercise['controllers'][setIndex];
                              Map<String, FocusNode> focusNodes =
                              exercise['focusNodes'][setIndex];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Set ${setIndex + 1}"),
                                  Expanded(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        if (set.containsKey('reps'))
                                          Container(
                                            width: 50,
                                            child: TextField(
                                              decoration: InputDecoration(labelText: "Reps"),
                                              keyboardType: TextInputType.number,
                                              controller: controllers['reps'],
                                              focusNode: focusNodes['reps'],
                                              onSubmitted: (value) {
                                                _verifyAndUpdateReps(exerciseIndex, setIndex, value);
                                              },
                                            ),
                                          ),
                                        if (set.containsKey('weight'))
                                          Container(
                                            width: 70,
                                            child: TextField(
                                              decoration: InputDecoration(labelText: "Weight (lbs)"),
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              controller: controllers['weight'],
                                              focusNode: focusNodes['weight'],
                                              onSubmitted: (value) {
                                                _verifyAndUpdateWeight(exerciseIndex, setIndex, value);
                                              },
                                            ),
                                          ),
                                        if (set.containsKey('duration'))
                                          Container(
                                            width: 70,
                                            child: TextField(
                                              decoration: InputDecoration(labelText: "Duration (sec)"),
                                              keyboardType: TextInputType.number,
                                              onChanged: (value) {
                                                _updateDuration(exerciseIndex, setIndex, int.tryParse(value) ?? 0);
                                              },
                                            ),
                                          ),
                                        if (set.containsKey('miles'))
                                          Container(
                                            width: 70,
                                            child: TextField(
                                              decoration: InputDecoration(labelText: "Miles"),
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              onChanged: (value) {
                                                _updateMiles(exerciseIndex, setIndex, double.tryParse(value) ?? 0.0);
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
    _workoutNameController.dispose();
    _workoutDescriptionController.dispose();
    for (var exercise in _selectedExercises) {
      if (exercise['controllers'] != null) {
        for (var ctrlMap in exercise['controllers']) {
          ctrlMap.values.forEach((c) => c.dispose());
        }
      }
      if (exercise['focusNodes'] != null) {
        for (var nodeMap in exercise['focusNodes']) {
          nodeMap.values.forEach((node) => node.dispose());
        }
      }
    }
    super.dispose();
  }
}
