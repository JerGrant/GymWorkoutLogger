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
    // Use themed colors from the current context
    final scaffoldBG = Theme.of(context).scaffoldBackgroundColor;
    final appBarBG = Theme.of(context).appBarTheme.backgroundColor;
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle;
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final labelStyle = textStyle?.copyWith(color: textStyle.color?.withOpacity(0.7));
    final dropdownBG = Theme.of(context).scaffoldBackgroundColor;
    final borderSide = BorderSide(color: Theme.of(context).dividerColor);

    return Scaffold(
      backgroundColor: scaffoldBG,
      appBar: AppBar(
        backgroundColor: appBarBG,
        surfaceTintColor: Colors.transparent,
        title: Text("Create New Exercise", style: titleStyle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Exercise Name
              TextField(
                controller: _nameController,
                style: textStyle,
                decoration: InputDecoration(
                  labelText: "Exercise Name",
                  labelStyle: labelStyle,
                  filled: true,
                  fillColor: scaffoldBG,
                  border: OutlineInputBorder(
                    borderSide: borderSide,
                  ),
                ),
              ),
              SizedBox(height: 16),

              /// Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: "Category",
                  labelStyle: labelStyle,
                  filled: true,
                  fillColor: scaffoldBG,
                  border: OutlineInputBorder(
                    borderSide: borderSide,
                  ),
                ),
                dropdownColor: dropdownBG,
                style: textStyle,
                items: categories
                    .map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: textStyle),
                ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
              ),
              SizedBox(height: 16),

              /// Body Part
              DropdownButtonFormField<String>(
                value: _selectedBodyPart,
                decoration: InputDecoration(
                  labelText: "Body Part",
                  labelStyle: labelStyle,
                  filled: true,
                  fillColor: scaffoldBG,
                  border: OutlineInputBorder(
                    borderSide: borderSide,
                  ),
                ),
                dropdownColor: dropdownBG,
                style: textStyle,
                items: bodyParts.keys
                    .map((part) => DropdownMenuItem(
                  value: part,
                  child: Text(part, style: textStyle),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBodyPart = value;
                    _selectedSubcategory = null;
                  });
                },
              ),
              SizedBox(height: 16),

              /// Subcategory (Conditional)
              if (_selectedBodyPart != null && bodyParts[_selectedBodyPart]!.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedSubcategory,
                  decoration: InputDecoration(
                    labelText: "Subcategory",
                    labelStyle: labelStyle,
                    filled: true,
                    fillColor: scaffoldBG,
                    border: OutlineInputBorder(
                      borderSide: borderSide,
                    ),
                  ),
                  dropdownColor: dropdownBG,
                  style: textStyle,
                  items: bodyParts[_selectedBodyPart]!
                      .map((subPart) => DropdownMenuItem(
                    value: subPart,
                    child: Text(subPart, style: textStyle),
                  ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedSubcategory = value),
                ),
              SizedBox(height: 16),

              /// Description (Optional)
              TextField(
                controller: _descriptionController,
                style: textStyle,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Description (Optional)",
                  labelStyle: labelStyle,
                  filled: true,
                  fillColor: scaffoldBG,
                  border: OutlineInputBorder(
                    borderSide: borderSide,
                  ),
                ),
              ),
              SizedBox(height: 20),

              /// Save Button
              Center(
                child: ElevatedButton(
                  onPressed: _saveExercise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Text("Save Exercise", style: textStyle?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
