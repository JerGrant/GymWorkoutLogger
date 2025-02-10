import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateExercisePage extends StatefulWidget {
  @override
  _CreateExercisePageState createState() => _CreateExercisePageState();
}

class _CreateExercisePageState extends State<CreateExercisePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedBodyPart;
  String? _selectedSubcategory;

  final List<String> categories = [
    "Barbell", "Dumbbell", "Cables", "Machine", "Other",
    "Weighted Bodyweight", "Assisted Body", "Laps", "Reps", "Cardio Exercises",
    "Duration", "Kettlebell", "Plyometrics", "Resistance Bands", "Isometrics",
    "Stretching & Mobility"
  ];

  final Map<String, List<String>> bodyParts = {
    "Core": [],
    "Arms": ["Biceps", "Triceps"],
    "Back": ["Traps", "Lats", "Lower Back"],
    "Chest": [],
    "Legs": ["Quads", "Calves", "Hamstrings", "Glutes"],
    "Shoulders": ["Front Delts", "Side Delts", "Rear Delts"],
    "Other": [],
    "Cardio": [],
    "Swimming": [],
    "Full Body": []
  };

  void _saveExercise() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User not logged in")));
      return;
    }

    if (_nameController.text.isEmpty || _selectedCategory == null || _selectedBodyPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exercises')
          .add({
        'userId': user.uid,  // Ensure the user ID is stored with the exercise
        'name': _nameController.text,
        'category': _selectedCategory,
        'bodyPart': _selectedBodyPart,
        'subcategory': _selectedSubcategory,
        'description': _descriptionController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, {
        'name': _nameController.text,
        'category': _selectedCategory,
        'bodyPart': _selectedBodyPart,
        'subcategory': _selectedSubcategory,
        'description': _descriptionController.text,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save exercise: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create New Exercise")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Exercise Name"),
            ),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(labelText: "Category"),
              items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
              onChanged: (value) => setState(() => _selectedCategory = value),
            ),
            DropdownButtonFormField<String>(
              value: _selectedBodyPart,
              decoration: InputDecoration(labelText: "Body Part"),
              items: bodyParts.keys.map((part) => DropdownMenuItem(value: part, child: Text(part))).toList(),
              onChanged: (value) => setState(() {
                _selectedBodyPart = value;
                _selectedSubcategory = null; // Reset subcategory when body part changes
              }),
            ),
            if (_selectedBodyPart != null && bodyParts[_selectedBodyPart]!.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedSubcategory,
                decoration: InputDecoration(labelText: "Subcategory"),
                items: bodyParts[_selectedBodyPart]!
                    .map((subPart) => DropdownMenuItem(value: subPart, child: Text(subPart)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSubcategory = value),
              ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: "Description (Optional)"),
              maxLines: 3,
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _saveExercise,
                child: Text("Save Exercise"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
