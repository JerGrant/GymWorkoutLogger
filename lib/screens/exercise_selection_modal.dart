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
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Initialize selectedExercises as empty list, so no exercises are pre-selected.
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
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('exercises')
                  .where('userId', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                var exercises = snapshot.data!.docs.where((exercise) {
                  var data = exercise.data() as Map<String, dynamic>;
                  return data['name'].toLowerCase().contains(searchQuery.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    var data = exercises[index].data() as Map<String, dynamic>;

                    // Always set exercises as unchecked since we're not tracking state across modal openings
                    bool isSelected = selectedExercises.any((ex) => ex['name'] == data['name']);

                    return CheckboxListTile(
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Text("Category: ${data['category']}, Body Part: ${data['bodyPart']}"),
                      value: isSelected, // Correctly set the checkbox state
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            // Add exercise to selectedExercises when it's checked
                            selectedExercises.add(Map<String, dynamic>.from(data));
                          } else {
                            // Remove exercise from selectedExercises when unchecked
                            selectedExercises.removeWhere((ex) => ex['name'] == data['name']);
                          }
                        });
                      },
                    );
                  },
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
              widget.onExercisesSelected(selectedExercises);  // Pass selected exercises back to the session
              Navigator.pop(context);
            },
            child: Icon(Icons.check),
          ),
        ],
      ),
    );
  }
}
