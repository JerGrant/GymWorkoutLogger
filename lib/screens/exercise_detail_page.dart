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
  String selectedBodyPart = "";

  final List<String> categories = [
    "Barbell", "Dumbbell", "Cables", "Machine", "Other", "Weighted Bodyweight",
    "Assisted Body", "Laps", "Reps", "Cardio Exercises", "Duration", "Kettlebell",
    "Plyometrics", "Resistance Bands", "Isometrics", "Stretching & Mobility"
  ];

  final List<String> bodyParts = [
    "Core", "Arms", "Biceps", "Triceps", "Back", "Traps", "Lats", "Lower Back",
    "Chest", "Shoulders", "Front Delts", "Side Delts", "Rear Delts", "Legs", "Quads",
    "Calves", "Hamstrings", "Glutes", "Other", "Cardio", "Swimming", "Full Body"
  ];

  @override
  void initState() {
    super.initState();
    var data = widget.exercise.data() as Map<String, dynamic>? ?? {};
    _nameController.text = data["name"] ?? "";
    _descriptionController.text = data["description"] ?? "";
    _notesController.text = data["notes"] ?? "";
    selectedCategory = data["category"] ?? categories.first;
    selectedBodyPart = data["bodyPart"] ?? bodyParts.first;
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
        'bodyPart': selectedBodyPart,
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
    ) ?? false;
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
            DropdownButtonFormField(
              value: selectedBodyPart,
              items: bodyParts.map((bodyPart) => DropdownMenuItem(value: bodyPart, child: Text(bodyPart))).toList(),
              onChanged: (value) {
                setState(() {
                  selectedBodyPart = value.toString();
                });
              },
              decoration: InputDecoration(labelText: "Body Part"),
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
