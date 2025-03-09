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

  // Text Controllers
  TextEditingController _nameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  TextEditingController _notesController = TextEditingController();

  // Dropdown values
  String selectedCategory = "";
  String? selectedMainBodyPart; // e.g. "Legs"
  String? selectedSubBodyPart;  // e.g. "Hamstrings"

  /// List of categories for the "Category" dropdown
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

  /// Hierarchy: Main body part -> possible sub-muscle groups
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

    /// Grab existing Firestore data
    var data = widget.exercise.data() as Map<String, dynamic>? ?? {};
    debugPrint(">>> Firestore raw data: $data");

    // Populate text fields
    _nameController.text = data["name"] ?? "";
    _descriptionController.text = data["description"] ?? "";
    _notesController.text = data["notes"] ?? "";

    // Populate category (or default to the first in the list)
    selectedCategory = data["category"] ?? categories.first;

    // Read new fields if present
    String? mainBP = data["mainBodyPart"];
    String? subBP = data["subBodyPart"];

    // Fallback to older fields if new ones are missing
    String? oldMain = data["bodyPart"];
    String? oldSub = data["subcategory"];

    if (mainBP == null || mainBP.isEmpty) {
      mainBP = oldMain; // e.g., "Shoulders"
    }
    if (subBP == null || subBP.isEmpty) {
      subBP = oldSub; // e.g., "Front Delts"
    }

    // Ensure subBP is valid for mainBP
    if (mainBP != null && mainBP.isNotEmpty) {
      final validSubs = bodyPartHierarchy[mainBP] ?? [];
      if (subBP != null && subBP.isNotEmpty && !validSubs.contains(subBP)) {
        debugPrint("WARNING: subBodyPart '$subBP' not found in $validSubs. Setting subBP to null.");
        subBP = null;
      }
    }

    selectedMainBodyPart = (mainBP != null && mainBP.isNotEmpty) ? mainBP : null;
    selectedSubBodyPart = (subBP != null && subBP.isNotEmpty) ? subBP : null;

    // Fallback if still no valid main part
    if (selectedMainBodyPart == null ||
        !bodyPartHierarchy.containsKey(selectedMainBodyPart)) {
      selectedMainBodyPart = "Other";
    }

    debugPrint(">>> final mainBP: $selectedMainBodyPart");
    debugPrint(">>> final subBP: $selectedSubBodyPart");
  }

  /// Save updates to Firestore
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
        // Store both new and old fields for compatibility:
        'mainBodyPart': selectedMainBodyPart,
        'subBodyPart': selectedSubBodyPart,
        'bodyPart': selectedMainBodyPart,
        'subcategory': selectedSubBodyPart,
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

  /// Delete this exercise from Firestore
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

  /// Fetch ALL occurrences of this exercise, find personal best, then last 10
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

  /// READ-ONLY view: show best volume up top, then last 10
  Widget _buildReadOnlyView(AsyncSnapshot<Map<String, dynamic>> snapshot) {
    final data = widget.exercise.data() as Map<String, dynamic>? ?? {};
    final exerciseName = data["name"] ?? "";
    final exerciseCategory = data["category"] ?? "";

    // For backward compatibility, use new fields if present; otherwise fallback
    final exerciseMainBodyPart = data["mainBodyPart"] ?? data["bodyPart"] ?? "Other";
    final exerciseSubBodyPart = data["subBodyPart"] ?? data["subcategory"] ?? "";

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
          Text(
            "Name: $exerciseName",
            // Updated to use theme text style
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("Category: $exerciseCategory", style: Theme.of(context).textTheme.bodyMedium),
          Text("Main Body Part: $exerciseMainBodyPart", style: Theme.of(context).textTheme.bodyMedium),
          if (exerciseSubBodyPart.isNotEmpty)
            Text("Specific Muscle Group: $exerciseSubBodyPart", style: Theme.of(context).textTheme.bodyMedium),
          if (exerciseDescription.isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Description: $exerciseDescription", style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (exerciseNotes.isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Notes: $exerciseNotes", style: Theme.of(context).textTheme.bodyMedium),
          ],
          SizedBox(height: 20),

          // Personal Best
          Text("Personal Best", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
          if (bestEntry == null)
            Text("No data found.", style: Theme.of(context).textTheme.bodyMedium)
          else
            Card(
              // Updated to use theme card color
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text(
                  "Date: ${bestEntry['date'].toLocal().toString().split('.')[0]}",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: _buildEntrySubtitle(bestEntry),
              ),
            ),

          SizedBox(height: 20),

          // Recent History
          Text("Recent History", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
          if (recent.isEmpty)
            Text("No recent data found.", style: Theme.of(context).textTheme.bodyMedium)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: recent.length,
              itemBuilder: (context, index) {
                var entry = recent[index];
                return Card(
                  color: Theme.of(context).cardColor,
                  margin: EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      "${entry['date'].toLocal().toString().split('.')[0]}",
                      style: Theme.of(context).textTheme.bodyMedium,
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

  /// Helper to build text showing volume & set details
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
        Text("Volume: ${volume.toStringAsFixed(1)}", style: Theme.of(context).textTheme.bodySmall),
        Text(setDetails, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// EDIT view: text fields, dropdowns, etc.
  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Exercise Name
          TextField(
            controller: _nameController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: "Exercise Name",
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              // Updated to use scaffold background color
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                // Updated border color
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Category
          DropdownButtonFormField(
            value: selectedCategory,
            // Updated to use scaffold background color
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            style: Theme.of(context).textTheme.bodyMedium,
            items: categories.map((category) {
              return DropdownMenuItem(value: category, child: Text(category, style: Theme.of(context).textTheme.bodyMedium));
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value.toString();
              });
            },
            decoration: InputDecoration(
              labelText: "Category",
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Main Body Part
          DropdownButtonFormField<String>(
            value: bodyPartHierarchy.containsKey(selectedMainBodyPart)
                ? selectedMainBodyPart
                : null,
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            style: Theme.of(context).textTheme.bodyMedium,
            items: bodyPartHierarchy.keys.map((mainPart) {
              return DropdownMenuItem(
                value: mainPart,
                child: Text(mainPart, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedMainBodyPart = value;
                selectedSubBodyPart = null;
              });
            },
            decoration: InputDecoration(
              labelText: "Main Body Part",
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Sub Body Part
          if (selectedMainBodyPart != null && bodyPartHierarchy[selectedMainBodyPart]!.isNotEmpty)
            DropdownButtonFormField<String>(
              value: bodyPartHierarchy[selectedMainBodyPart!]!.contains(selectedSubBodyPart)
                  ? selectedSubBodyPart
                  : null,
              dropdownColor: Theme.of(context).scaffoldBackgroundColor,
              style: Theme.of(context).textTheme.bodyMedium,
              items: bodyPartHierarchy[selectedMainBodyPart!]!.map((subPart) {
                return DropdownMenuItem(
                  value: subPart,
                  child: Text(subPart, style: Theme.of(context).textTheme.bodyMedium),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubBodyPart = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Specific Muscle Group",
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          SizedBox(height: 8),

          // Description
          TextField(
            controller: _descriptionController,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Description",
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Notes
          TextField(
            controller: _notesController,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Notes",
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Updated from hardcoded Color(0xFF000015)
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // Updated
            surfaceTintColor: Colors.transparent,
            iconTheme: Theme.of(context).appBarTheme.iconTheme, // Updated
            title: Text("Exercise Details", style: Theme.of(context).appBarTheme.titleTextStyle), // Updated
            actions: [
              // Edit / Save icon
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit, color: Theme.of(context).colorScheme.primary), // Updated
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
                icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), // Updated
                onPressed: _deleteExercise,
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)) // Updated
              : _isEditing
              ? _buildEditView()
              : _buildReadOnlyView(snapshot),
        );
      },
    );
  }
}
