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
  int _duration = 0;
  String _workoutName = "Untitled Workout";
  String _workoutDescription = "";
  DocumentReference? _workoutRef;
  List<Map<String, dynamic>> _selectedExercises = [];

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
              _selectedExercises.addAll(selected);
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
            Text("Duration: ${_formatDuration(_duration)}", style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openExerciseSelection,
              child: Text('Add Exercise'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _selectedExercises.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_selectedExercises[index]['name'] ?? 'Unnamed Exercise'),
                    subtitle: Text("Category: ${_selectedExercises[index]['category']}, Body Part: ${_selectedExercises[index]['bodyPart']}"),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeExercise(index),
                    ),
                  );
                },
              ),
            ),
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

class ExerciseSelectionModal extends StatefulWidget {
  final List<Map<String, dynamic>> alreadySelectedExercises;
  final Function(List<Map<String, dynamic>>) onExercisesSelected;

  ExerciseSelectionModal({required this.alreadySelectedExercises, required this.onExercisesSelected});

  @override
  _ExerciseSelectionModalState createState() => _ExerciseSelectionModalState();
}

class _ExerciseSelectionModalState extends State<ExerciseSelectionModal> {
  List<Map<String, dynamic>> selectedExercises = [];
  String searchQuery = "";
  String? selectedCategory;
  String? selectedBodyPart;
  String selectedSort = "Alphabetical";

  final Map<String, List<String>> bodyPartHierarchy = {
    "Shoulders": ["Front Delts", "Side Delts", "Rear Delts"],
    "Chest": [],
    "Arms": ["Biceps", "Triceps", "Forearms"],
    "Back": ["Lats", "Traps", "Lower Back"],
    "Core": ["Upper Abs", "Lower Abs", "Obliques"],
    "Legs": ["Quads", "Hamstrings", "Calves", "Glutes"],
    "Full Body": [],
    "Cardio": [],
    "Other": [],
  };

  final List<String> categories = [
    "Barbell",
    "Dumbbell",
    "Machine",
    "Cardio",
    "Other",
  ];

  final List<String> sortOptions = [
    "Alphabetical",
    "Body Part",
    "Category",
  ];

  @override
  void initState() {
    super.initState();
    selectedExercises = [];
  }

  List<QueryDocumentSnapshot<Object?>> applyFilters(List<QueryDocumentSnapshot<Object?>> exercises) {
    return exercises.where((exercise) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      bool matchesSearch = data['name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false;

      bool matchesBodyPart = true;
      if (selectedBodyPart != null) {
        if (bodyPartHierarchy.containsKey(selectedBodyPart!)) {
          List<String> subParts = bodyPartHierarchy[selectedBodyPart!] ?? [];
          matchesBodyPart = subParts.contains(data['bodyPart']) || data['bodyPart'] == selectedBodyPart;
        } else {
          matchesBodyPart = data['bodyPart'] == selectedBodyPart;
        }
      }

      bool matchesCategory = selectedCategory == null || data['category'] == selectedCategory;

      return matchesSearch && matchesBodyPart && matchesCategory;
    }).toList();
  }

  List<QueryDocumentSnapshot<Object?>> applySorting(
      List<QueryDocumentSnapshot<Object?>> exercises) {
    if (selectedSort == "Alphabetical") {
      exercises.sort((a, b) =>
          (a.data() as Map<String, dynamic>)['name']
              .toString()
              .compareTo((b.data() as Map<String, dynamic>)['name'].toString()));
    } else if (selectedSort == "Body Part") {
      exercises.sort((a, b) =>
          (a.data() as Map<String, dynamic>)['bodyPart']
              .toString()
              .compareTo((b.data() as Map<String, dynamic>)['bodyPart'].toString()));
    } else if (selectedSort == "Category") {
      exercises.sort((a, b) =>
          (a.data() as Map<String, dynamic>)['category']
              .toString()
              .compareTo((b.data() as Map<String, dynamic>)['category'].toString()));
    }
    return exercises;
  }

  Map<String, List<QueryDocumentSnapshot<Object?>>> groupByField(
      List<QueryDocumentSnapshot<Object?>> exercises, String field) {
    Map<String, List<QueryDocumentSnapshot<Object?>>> grouped = {};

    for (var exercise in exercises) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      String key = data[field]?.toString() ?? "Unknown";

      if (field == "name" && key.isNotEmpty) {
        key = key[0].toUpperCase();
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(exercise);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Exercises'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search Exercises",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: [
                      DropdownMenuItem(value: null, child: Text("All Categories")),
                      ...categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                    decoration: InputDecoration(labelText: "Category"),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedBodyPart,
                    items: [
                      DropdownMenuItem(value: null, child: Text("All Body Parts")),
                      ...bodyPartHierarchy.entries.expand((entry) {
                        String parent = entry.key;
                        List<String> subcategories = entry.value;
                        return [
                          DropdownMenuItem(
                            value: parent,
                            child: Text(
                              parent,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...subcategories.map((subcategory) => DropdownMenuItem(
                            value: subcategory,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16.0),
                              child: Text("— $subcategory"),
                            ),
                          )),
                        ];
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedBodyPart = value;
                      });
                    },
                    decoration: InputDecoration(labelText: "Body Part"),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: selectedSort,
              items: sortOptions.map((sort) => DropdownMenuItem(
                value: sort,
                child: Text(sort),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSort = value!;
                });
              },
              decoration: InputDecoration(labelText: "Sort By"),
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                var exercises = applyFilters(snapshot.data!.docs);
                exercises = applySorting(exercises);

                Map<String, List<QueryDocumentSnapshot<Object?>>> groupedExercises;
                if (selectedSort == "Body Part") {
                  groupedExercises = groupByField(exercises, "bodyPart");
                } else if (selectedSort == "Category") {
                  groupedExercises = groupByField(exercises, "category");
                } else {
                  groupedExercises = groupByField(exercises, "name");
                }

                var sortedKeys = groupedExercises.keys.toList()..sort();

                return ListView.builder(
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, groupIndex) {
                    String groupKey = sortedKeys[groupIndex];
                    List<QueryDocumentSnapshot<Object?>> groupExercises = groupedExercises[groupKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (groupExercises.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              groupKey,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ...groupExercises.map((exercise) {
                          var data = exercise.data() as Map<String, dynamic>? ?? {};
                          return CheckboxListTile(
                            title: Text(data['name'] ?? 'Unknown'),
                            subtitle: Text(
                              "Category: ${data['category']}, Body Part: ${data['bodyPart']}",
                            ),
                            value: selectedExercises.any((ex) => ex['name'] == data['name']),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedExercises.add(Map<String, dynamic>.from(data));
                                } else {
                                  selectedExercises.removeWhere((ex) => ex['name'] == data['name']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          widget.onExercisesSelected(selectedExercises);
          Navigator.pop(context);
        },
        child: Icon(Icons.check),
      ),
    );
  }
}
