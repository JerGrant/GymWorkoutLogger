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
    "Barbell",
    "Dumbbell",
    "Cables",
    "Machine",
    "Other",
    "Weighted Bodyweight",
    "Assisted Body",
    "Laps",
    "Reps",
    "Cardio Exercises",
    "Duration",
    "Kettlebell",
    "Plyometrics",
    "Resistance Bands",
    "Isometrics",
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("User not logged in")));
      return;
    }
    if (_nameController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedBodyPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please fill all required fields")));
      return;
    }
    try {
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exercises')
          .add({
        'userId': user.uid,
        'name': _nameController.text,
        'category': _selectedCategory,
        'bodyPart': _selectedBodyPart,
        'subcategory': _selectedSubcategory,
        'description': _descriptionController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, {
        'id': docRef.id,
        'name': _nameController.text,
        'category': _selectedCategory,
        'bodyPart': _selectedBodyPart,
        'subcategory': _selectedSubcategory,
        'description': _descriptionController.text,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save exercise: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000015),
      appBar: AppBar(
        backgroundColor: Color(0xFF000015),
        surfaceTintColor: Colors.transparent, // Disables default tint
        title: Text("Create New Exercise", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// **Exercise Name**
              TextField(
                controller: _nameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Exercise Name",
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF000015),  // Matches the dark background
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              SizedBox(height: 16),

              /// **Category**
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: "Category",
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF000015),  // Matches the dark background
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                dropdownColor: Color(0xFF000015),
                style: TextStyle(color: Colors.white),
                items: categories.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              SizedBox(height: 16),

              /// **Body Part**
              DropdownButtonFormField<String>(
                value: _selectedBodyPart,
                decoration: InputDecoration(
                  labelText: "Body Part",
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF000015),  // Matches the dark background
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                dropdownColor: Color(0xFF000015),
                style: TextStyle(color: Colors.white),
                items: bodyParts.keys.map((part) => DropdownMenuItem(
                  value: part,
                  child: Text(part, style: TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBodyPart = value;
                    _selectedSubcategory = null;
                  });
                },
              ),
              SizedBox(height: 16),

              /// **Subcategory (Conditional)**
              if (_selectedBodyPart != null && bodyParts[_selectedBodyPart]!.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSubcategory,
                  decoration: InputDecoration(
                    labelText: "Subcategory",
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color(0xFF000015), // Matches the dark background
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  dropdownColor: Color(0xFF000015),
                  style: TextStyle(color: Colors.white),
                  items: bodyParts[_selectedBodyPart]!.map((subPart) => DropdownMenuItem(
                    value: subPart,
                    child: Text(subPart, style: TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedSubcategory = value),
                ),
              SizedBox(height: 16),

              /// **Description (Optional)**
              TextField(
                controller: _descriptionController,
                style: TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color(0xFF000015),  // Matches the dark background
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              SizedBox(height: 20),

              /// **Save Button**
              Center(
                child: ElevatedButton(
                  onPressed: _saveExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF007AFF),
                  ),
                  child: Text("Save Exercise", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
