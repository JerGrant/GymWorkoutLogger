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
  bool _isEditing = false;

  TextEditingController _nameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _notesController = TextEditingController();
  String selectedCategory = "";
  String? selectedMainBodyPart;
  String? selectedSubBodyPart;

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

    selectedSubBodyPart = data["bodyPart"];
    if (selectedSubBodyPart != null) {
      selectedMainBodyPart = bodyPartHierarchy.entries.firstWhere(
            (entry) => entry.value.contains(selectedSubBodyPart),
        orElse: () => const MapEntry("Other", []),
      ).key;
    }
    if (!bodyPartHierarchy.containsKey(selectedMainBodyPart)) {
      selectedMainBodyPart = null;
    }
  }

  /// Save updates to Firestore.
  void _updateExercise() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in.")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exercise updated successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update exercise: $e")),
      );
    }
  }

  /// Delete this exercise from Firestore.
  void _deleteExercise() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in.")),
      );
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Exercise deleted successfully!")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete exercise: $e")),
        );
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

  /// Fetch ALL occurrences of this exercise, find the personal best, then get the last 10 by date.
  Future<Map<String, dynamic>> _fetchExerciseHistory(String exerciseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'bestEntry': null, 'recent': []};

    final List<Map<String, dynamic>> allEntries = [];
    final workoutsSnapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    double maxVolume = 0.0;
    Map<String, dynamic>? bestEntry;

    for (var doc in workoutsSnapshot.docs) {
      Timestamp? ts = doc['timestamp'];
      DateTime workoutDate = ts != null ? ts.toDate() : DateTime.now();
      List exercises = doc['exercises'] ?? [];

      for (var ex in exercises) {
        if (ex['id'] == exerciseId) {
          double volume = 0.0;
          List sets = ex['sets'] ?? [];

          for (var set in sets) {
            if (set.containsKey('weight') && set.containsKey('reps')) {
              double weight = 0.0;
              int reps = 0;

              if (set['weight'] is int) {
                weight = (set['weight'] as int).toDouble();
              } else if (set['weight'] is double) {
                weight = set['weight'];
              }
              if (set['reps'] is int) {
                reps = set['reps'];
              } else {
                reps = int.tryParse(set['reps'].toString()) ?? 0;
              }
              volume += weight * reps;
            }
          }

          // Build the entry
          Map<String, dynamic> entry = {
            'date': workoutDate,
            'volume': volume,
            'sets': sets,
          };
          allEntries.add(entry);

          // Track best volume
          if (volume > maxVolume) {
            maxVolume = volume;
            bestEntry = entry;
          }
        }
      }
    }

    // Sort all entries by date descending
    allEntries.sort((a, b) => b['date'].compareTo(a['date']));

    // Remove the best entry from the list if present, so we don't duplicate it
    if (bestEntry != null) {
      allEntries.remove(bestEntry);
    }

    // The "recent" list is the next 10 entries
    final recent = allEntries.take(10).toList();

    return {
      'bestEntry': bestEntry,
      'recent': recent,
    };
  }

  /// READ-ONLY view: show best volume up top, then last 10.
  Widget _buildReadOnlyView(AsyncSnapshot<Map<String, dynamic>> snapshot) {
    final data = widget.exercise.data() as Map<String, dynamic>? ?? {};
    final exerciseName = data["name"] ?? "";
    final exerciseCategory = data["category"] ?? "";
    final exerciseBodyPart = data["bodyPart"] ?? "";
    final exerciseDescription = data["description"] ?? "";
    final exerciseNotes = data["notes"] ?? "";

    // Data from the future builder
    final bestEntry = snapshot.data?['bestEntry'] as Map<String, dynamic>?;
    final recent = snapshot.data?['recent'] as List<Map<String, dynamic>>? ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic info
          Text("Name: $exerciseName",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text("Category: $exerciseCategory"),
          Text("Body Part: $exerciseBodyPart"),
          if (exerciseDescription.isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Description: $exerciseDescription"),
          ],
          if (exerciseNotes.isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Notes: $exerciseNotes"),
          ],
          SizedBox(height: 20),

          // Personal Best
          Text("Personal Best",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (bestEntry == null)
            Text("No data found.")
          else
            Card(
              color: Colors.amber.shade50,
              child: ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text(
                  "Date: ${bestEntry['date'].toLocal().toString().split('.')[0]}",
                ),
                subtitle: _buildEntrySubtitle(bestEntry),
              ),
            ),

          SizedBox(height: 20),

          // Recent History
          Text("Recent History",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (recent.isEmpty)
            Text("No recent data found.")
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              itemBuilder: (context, index) {
                var entry = recent[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      "${entry['date'].toLocal().toString().split('.')[0]}",
                    ),
                    subtitle: _buildEntrySubtitle(entry),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Helper to build the text showing volume & set details.
  Widget _buildEntrySubtitle(Map<String, dynamic> entry) {
    double volume = entry['volume'] ?? 0.0;
    List sets = entry['sets'] ?? [];

    String setDetails = sets.asMap().entries.map((e) {
      int setNum = e.key + 1;
      var set = e.value;
      var weight = set.containsKey('weight') ? set['weight'] : '-';
      var reps = set.containsKey('reps') ? set['reps'] : '-';
      return "Set $setNum: ${weight}lbs x ${reps} reps";
    }).join("\n");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Volume: ${volume.toStringAsFixed(1)}"),
        Text(setDetails),
      ],
    );
  }

  /// EDIT view: text fields, dropdowns, etc.
  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: "Exercise Name"),
          ),
          SizedBox(height: 8),
          DropdownButtonFormField(
            value: selectedCategory,
            items: categories.map((category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value.toString();
              });
            },
            decoration: InputDecoration(labelText: "Category"),
          ),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: bodyPartHierarchy.containsKey(selectedMainBodyPart)
                ? selectedMainBodyPart
                : null,
            items: bodyPartHierarchy.keys.map((mainPart) {
              return DropdownMenuItem(
                value: mainPart,
                child: Text(
                  mainPart,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedMainBodyPart = value;
                selectedSubBodyPart = null;
              });
            },
            decoration: InputDecoration(labelText: "Main Body Part"),
          ),
          if (selectedMainBodyPart != null &&
              bodyPartHierarchy[selectedMainBodyPart]!.isNotEmpty)
            DropdownButtonFormField<String>(
              value: bodyPartHierarchy[selectedMainBodyPart]!
                  .contains(selectedSubBodyPart)
                  ? selectedSubBodyPart
                  : null,
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
          SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: "Description"),
            maxLines: 3,
          ),
          SizedBox(height: 8),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(labelText: "Notes"),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchExerciseHistory(widget.exercise.id),
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: Text("Exercise Details"),
            actions: [
              // Edit / Save icon
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                onPressed: () {
                  if (_isEditing) {
                    // If user was editing, save changes
                    _updateExercise();
                  }
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
              ),
              // Delete icon
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: _deleteExercise,
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? Center(child: CircularProgressIndicator())
              : _isEditing
              ? _buildEditView()
              : _buildReadOnlyView(snapshot),
        );
      },
    );
  }
}
