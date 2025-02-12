import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExerciseDetailsPage extends StatefulWidget {
  final DocumentSnapshot exercise;

  ExerciseDetailsPage({required this.exercise});

  @override
  _ExerciseDetailsPageState createState() => _ExerciseDetailsPageState();
}

class _ExerciseDetailsPageState extends State<ExerciseDetailsPage> {
  TextEditingController _nameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  String selectedCategory = "";
  String? selectedMainBodyPart;
  String? selectedSubBodyPart;

  final List<String> categories = [
    "Barbell", "Dumbbell", "Cables", "Machine", "Other", "Weighted Bodyweight",
    "Assisted Body", "Laps", "Reps", "Cardio Exercises", "Duration", "Kettlebell",
    "Plyometrics", "Resistance Bands", "Isometrics", "Stretching & Mobility"
  ];

  // Main body part categories with subcategories
  final Map<String, List<String>> bodyPartHierarchy = {
    "Arms": ["Biceps", "Triceps", "Forearms"],
    "Back": ["Traps", "Lats", "Lower Back"],
    "Shoulders": ["Front Delts", "Side Delts", "Rear Delts"],
    "Legs": ["Quads", "Hamstrings", "Calves", "Glutes"],
    "Core": ["Upper Abs", "Lower Abs", "Obliques"],
    "Chest": [],
    "Full Body": [],
    "Cardio": [],
    "Swimming": [],
    "Other": [],
  };

  @override
  void initState() {
    super.initState();
    var data = widget.exercise.data() as Map<String, dynamic>? ?? {};
    _nameController.text = data["name"] ?? "";
    _descriptionController.text = data["description"] ?? "";
    _notesController.text = data["notes"] ?? "";
    selectedCategory = data["category"] ?? categories.first;

    // Set initial body part selections
    selectedSubBodyPart = data["bodyPart"];

    // Ensure the selected sub-body part exists
    if (selectedSubBodyPart != null) {
      selectedMainBodyPart = bodyPartHierarchy.entries.firstWhere(
            (entry) => entry.value.contains(selectedSubBodyPart),
        orElse: () => const MapEntry("Other", []),
      ).key;
    }

    // Ensure main body part is valid, or set it to null
    if (!bodyPartHierarchy.containsKey(selectedMainBodyPart)) {
      selectedMainBodyPart = null;
    }
  }

  void _updateExercise() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User not logged in.")));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exercises')
          .doc(widget.exercise.id)
          .update({
        'name': _nameController.text,
        'category': selectedCategory,
        'bodyPart': selectedSubBodyPart,
        'description': _descriptionController.text,
        'notes': _notesController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exercise updated successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update exercise: $e")));
    }
  }

  void _deleteExercise() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User not logged in.")));
      return;
    }

    bool confirmDelete = await _showDeleteConfirmation();
    if (confirmDelete) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('exercises')
            .doc(widget.exercise.id)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exercise deleted successfully!")));
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete exercise: $e")));
      }
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Exercise"),
        content: Text("Are you sure you want to delete this exercise?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Delete"),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Exercise"),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteExercise,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Exercise Name"),
            ),
            DropdownButtonFormField(
              value: selectedCategory,
              items: categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value.toString();
                });
              },
              decoration: InputDecoration(labelText: "Category"),
            ),

            // **Main Body Part Dropdown**
            DropdownButtonFormField<String>(
              value: bodyPartHierarchy.containsKey(selectedMainBodyPart) ? selectedMainBodyPart : null,
              items: bodyPartHierarchy.keys.map((mainPart) {
                return DropdownMenuItem(
                  value: mainPart,
                  child: Text(mainPart, style: TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedMainBodyPart = value;
                  selectedSubBodyPart = null; // Reset subcategory when main part changes
                });
              },
              decoration: InputDecoration(labelText: "Main Body Part"),
            ),

            // **Sub Body Part Dropdown (Appears only when necessary)**
            if (selectedMainBodyPart != null && bodyPartHierarchy[selectedMainBodyPart]!.isNotEmpty)
              DropdownButtonFormField<String>(
                value: bodyPartHierarchy[selectedMainBodyPart]!.contains(selectedSubBodyPart) ? selectedSubBodyPart : null,
                items: bodyPartHierarchy[selectedMainBodyPart]!.map((subPart) {
                  return DropdownMenuItem(
                    value: subPart,
                    child: Text(subPart),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSubBodyPart = value;
                  });
                },
                decoration: InputDecoration(labelText: "Specific Muscle Group"),
              ),

            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: "Notes"),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  _updateExercise();
                  Navigator.pop(context);
                },
                child: Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
