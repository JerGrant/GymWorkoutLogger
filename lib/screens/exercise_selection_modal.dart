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

  /// Create a new exercise, add it to Firestore, and auto-add to selectedExercises.
  Future<void> _createNewExercise() async {
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateExercisePage()),
    );

    if (newExercise != null) {
      // Check if it's already in selectedExercises
      bool alreadySelected = selectedExercises.any((ex) => ex['id'] == newExercise['id']);
      if (!alreadySelected) {
        setState(() {
          // Auto-add the newly created exercise
          selectedExercises.add(newExercise);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Exercises'),
      ),
      body: Column(
        children: [
          // Search field
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

          // Sort dropdown
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

          // Exercise list
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('exercises')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                // Convert Firestore docs to local List<Map<String, dynamic>>
                var exercises = snapshot.data!.docs.map((doc) {
                  return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
                }).toList();

                // Filter by search query
                exercises = exercises.where((data) {
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(searchQuery.toLowerCase());
                }).toList();

                // Sort based on user selection
                exercises.sort((a, b) {
                  final aName = (a['name'] ?? '').toString();
                  final bName = (b['name'] ?? '').toString();
                  final aCategory = (a['category'] ?? '').toString();
                  final bCategory = (b['category'] ?? '').toString();
                  final aBody = (a['bodyPart'] ?? '').toString();
                  final bBody = (b['bodyPart'] ?? '').toString();

                  if (sortBy == "Name") {
                    return aName.compareTo(bName);
                  } else if (sortBy == "Category") {
                    return aCategory.compareTo(bCategory);
                  } else if (sortBy == "Body Part") {
                    return aBody.compareTo(bBody);
                  }
                  return 0;
                });

                // Grouping logic
                Map<String, List<Map<String, dynamic>>> groupedExercises = {};
                for (var exercise in exercises) {
                  // Decide the header based on sortBy
                  String header;
                  if (sortBy == "Category") {
                    header = (exercise['category'] ?? 'Unknown').toString();
                  } else if (sortBy == "Body Part") {
                    header = (exercise['bodyPart'] ?? 'Unknown').toString();
                  } else {
                    // "Name" or fallback
                    final name = (exercise['name'] ?? 'Unknown').toString();
                    header = name.isNotEmpty ? name[0].toUpperCase() : 'Unknown';
                  }

                  if (!groupedExercises.containsKey(header)) {
                    groupedExercises[header] = [];
                  }
                  groupedExercises[header]!.add(exercise);
                }

                // Build list UI
                return ListView(
                  children: groupedExercises.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group header
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            entry.key,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Items in this group
                        ...entry.value.map((data) {
                          // If data is in selectedExercises, it's "checked"
                          bool isSelected = selectedExercises.any((ex) => ex['id'] == data['id']);
                          return CheckboxListTile(
                            title: Text(data['name'] ?? 'Unknown'),
                            subtitle: Text(
                              "Category: ${data['category'] ?? 'N/A'}, "
                                  "Body Part: ${data['bodyPart'] ?? 'N/A'}",
                            ),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  // Only add if not already in list
                                  bool alreadySelected = selectedExercises.any(
                                        (ex) => ex['id'] == data['id'],
                                  );
                                  if (!alreadySelected) {
                                    selectedExercises.add(data);
                                  }
                                } else {
                                  // Uncheck => remove from list
                                  selectedExercises.removeWhere((ex) => ex['id'] == data['id']);
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

      // Two FABs => unique heroTags
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "fabCreateExercise", // Unique tag
            onPressed: _createNewExercise,
            child: Icon(Icons.add),
            tooltip: 'Create New Exercise',
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "fabConfirmSelection", // Unique tag
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
