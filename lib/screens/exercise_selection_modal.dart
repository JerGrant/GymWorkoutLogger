import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gymworkoutlogger/screens/create_exercise_page.dart';

class ExerciseSelectionModal extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onExercisesSelected;

  ExerciseSelectionModal({required this.onExercisesSelected});

  @override
  _ExerciseSelectionModalState createState() => _ExerciseSelectionModalState();
}

class _ExerciseSelectionModalState extends State<ExerciseSelectionModal> {
  List<Map<String, dynamic>> selectedExercises = [];
  String searchQuery = "";
  String sortBy = "Name"; // Default sorting option
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    selectedExercises = [];
  }

  Future<void> _createNewExercise() async {
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateExercisePage()),
    );

    if (newExercise != null) {
      setState(() {
        selectedExercises.add(newExercise);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Exercises')),
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
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Sort By",
                border: OutlineInputBorder(),
              ),
              value: sortBy,
              items: ["Name", "Category", "Body Part"].map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  sortBy = value ?? "Name";
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('exercises')
                  .where('userId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                var exercises = snapshot.data!.docs.map((doc) {
                  return doc.data() as Map<String, dynamic>;
                }).where((data) {
                  return data['name'].toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                // Sorting logic
                exercises.sort((a, b) {
                  if (sortBy == "Name") {
                    return a['name'].compareTo(b['name']);
                  } else if (sortBy == "Category") {
                    return a['category'].compareTo(b['category']);
                  } else if (sortBy == "Body Part") {
                    return a['bodyPart'].compareTo(b['bodyPart']);
                  }
                  return 0;
                });

                Map<String, List<Map<String, dynamic>>> groupedExercises = {};
                for (var exercise in exercises) {
                  String header = sortBy == "Category"
                      ? exercise['category']
                      : sortBy == "Body Part"
                      ? exercise['bodyPart']
                      : exercise['name'][0].toUpperCase();

                  if (!groupedExercises.containsKey(header)) {
                    groupedExercises[header] = [];
                  }
                  groupedExercises[header]!.add(exercise);
                }

                return ListView(
                  children: groupedExercises.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            entry.key,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...entry.value.map((data) {
                          bool isSelected = selectedExercises.any((ex) => ex['name'] == data['name']);
                          return CheckboxListTile(
                            title: Text(data['name'] ?? 'Unknown'),
                            subtitle: Text("Category: ${data['category']}, Body Part: ${data['bodyPart']}"),
                            value: isSelected,
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
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: _createNewExercise,
            child: Icon(Icons.add),
            tooltip: 'Create New Exercise',
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: () {
              widget.onExercisesSelected(selectedExercises);
              Navigator.pop(context);
            },
            child: Icon(Icons.check),
          ),
        ],
      ),
    );
  }
}
