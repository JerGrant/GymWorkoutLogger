import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  final List<String> categories = ["Barbell", "Dumbbell", "Machine", "Cardio", "Other"];
  final List<String> sortOptions = ["Alphabetical", "Body Part", "Category"];

  @override
  void initState() {
    super.initState();
    selectedExercises = [];
  }

  List<QueryDocumentSnapshot<Object?>> applyFilters(List<QueryDocumentSnapshot<Object?>> exercises) {
    return exercises.where((exercise) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      bool matchesSearch = data['name']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false;

      bool matchesBodyPart = selectedBodyPart == null || data['bodyPart'] == selectedBodyPart;
      bool matchesCategory = selectedCategory == null || data['category'] == selectedCategory;

      return matchesSearch && matchesBodyPart && matchesCategory;
    }).toList();
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
                setState(() { searchQuery = value; });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                var exercises = applyFilters(snapshot.data!.docs);
                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    var data = exercises[index].data() as Map<String, dynamic>;
                    return CheckboxListTile(
                      title: Text(data['name'] ?? 'Unknown'),
                      subtitle: Text("Category: ${data['category']}, Body Part: ${data['bodyPart']}"),
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
