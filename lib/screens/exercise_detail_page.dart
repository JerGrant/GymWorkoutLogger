import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:gymworkoutlogger/providers/unit_provider.dart';
import 'package:gymworkoutlogger/utils/unit_converter.dart';

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
  String? selectedMainBodyPart;
  String? selectedSubBodyPart;

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

  bool isCardioExercise = false;

  @override
  void initState() {
    super.initState();
    // Grab existing Firestore data
    var data = widget.exercise.data() as Map<String, dynamic>? ?? {};

    // Populate text fields
    _nameController.text = data["name"] ?? "";
    _descriptionController.text = data["description"] ?? "";
    _notesController.text = data["notes"] ?? "";

    // Populate category (or default to the first in the list)
    selectedCategory = data["category"] ?? categories.first;

    // Decide if this is a cardio exercise (customize logic as desired)
    // For example, if category == "Cardio Exercises"
    if (selectedCategory == "Cardio Exercises") {
      isCardioExercise = true;
    }

    // Read new fields if present
    String? mainBP = data["mainBodyPart"];
    String? subBP = data["subBodyPart"];

    // Fallback to older fields if new ones are missing
    String? oldMain = data["bodyPart"];
    String? oldSub = data["subcategory"];

    if (mainBP == null || mainBP.isEmpty) {
      mainBP = oldMain;
    }
    if (subBP == null || subBP.isEmpty) {
      subBP = oldSub;
    }

    // Ensure subBP is valid for mainBP
    if (mainBP != null && mainBP.isNotEmpty) {
      final validSubs = bodyPartHierarchy[mainBP] ?? [];
      if (subBP != null && subBP.isNotEmpty && !validSubs.contains(subBP)) {
        subBP = null;
      }
    }

    selectedMainBodyPart = (mainBP != null && mainBP.isNotEmpty) ? mainBP : "Other";
    selectedSubBodyPart = (subBP != null && subBP.isNotEmpty) ? subBP : null;
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
        // Store both new and old fields for compatibility
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

  /// Fetch ALL occurrences of this exercise:
  ///   - If cardio => personal best by highest distance (tie -> shorter duration)
  ///   - Else => personal best by total volume
  ///   - Return last 10 workouts as "recent"
  Future<Map<String, dynamic>> _fetchExerciseHistory(String exerciseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'bestEntry': null, 'recent': [], 'isCardio': isCardioExercise};

    final List<Map<String, dynamic>> allEntries = [];
    final workoutsSnapshot = await FirebaseFirestore.instance
        .collection('workouts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    // For cardio best
    double maxDistance = 0.0;
    int bestDuration = 999999999;
    Map<String, dynamic>? bestDistanceEntry;

    // For strength best
    double maxVolume = 0.0;
    Map<String, dynamic>? bestVolumeEntry;

    for (var doc in workoutsSnapshot.docs) {
      final ts = doc['timestamp'] as Timestamp?;
      DateTime workoutDate = ts != null ? ts.toDate() : DateTime.now();

      final exercises = doc['exercises'] ?? [];
      // We'll store all sets for "recent" display
      final setsForThisWorkout = <Map<String, dynamic>>[];

      for (var ex in exercises) {
        if (ex['id'] == exerciseId) {
          List sets = ex['sets'] ?? [];
          double workoutVolume = 0.0; // for strength
          for (var set in sets) {
            // Strength volume
            if (set.containsKey('weight') && set.containsKey('reps')) {
              double weight = 0.0;
              if (set['weight'] is int) {
                weight = (set['weight'] as int).toDouble();
              } else if (set['weight'] is double) {
                weight = set['weight'];
              }
              int reps = 0;
              if (set['reps'] is int) {
                reps = set['reps'];
              } else {
                reps = int.tryParse(set['reps'].toString()) ?? 0;
              }
              workoutVolume += weight * reps;
            }

            // Cardio distance
            double distanceVal =
                double.tryParse(set['distance']?.toString() ?? '') ?? 0.0;
            int durationVal = 0;
            if (set['duration'] != null) {
              durationVal = (set['duration'] is int)
                  ? set['duration']
                  : int.tryParse(set['duration'].toString()) ?? 0;
            }

            // Track best distance (tie -> shorter duration)
            if (distanceVal > 0) {
              if (distanceVal > maxDistance) {
                maxDistance = distanceVal;
                bestDuration = durationVal;
                bestDistanceEntry = {
                  'date': workoutDate,
                  'sets': [set],
                };
              } else if ((distanceVal == maxDistance) &&
                  (durationVal < bestDuration)) {
                bestDuration = durationVal;
                bestDistanceEntry = {
                  'date': workoutDate,
                  'sets': [set],
                };
              }
            }

            setsForThisWorkout.add(set);
          }

          // Check if this workout's total volume is new best
          if (workoutVolume > maxVolume) {
            maxVolume = workoutVolume;
            bestVolumeEntry = {
              'date': workoutDate,
              'sets': sets,
              'volume': workoutVolume,
            };
          }
        }
      }

      if (setsForThisWorkout.isNotEmpty) {
        allEntries.add({
          'date': workoutDate,
          'sets': setsForThisWorkout,
          // store volume if you want to show it in "recent" as well
          'volume': 0.0, // or track the actual volume if you prefer
        });
      }
    }

    // Sort by date desc
    allEntries.sort((a, b) => b['date'].compareTo(a['date']));

    // The "recent" list is the last 10 workouts for this exercise
    final recent = allEntries.take(10).toList();

    // Decide which personal best to return
    Map<String, dynamic>? bestEntry;
    if (isCardioExercise) {
      // Cardio best: highest distance, tie -> shorter duration
      bestEntry = bestDistanceEntry;
    } else {
      // Strength best: highest total volume
      bestEntry = bestVolumeEntry;
    }

    return {
      'bestEntry': bestEntry,
      'recent': recent,
      'isCardio': isCardioExercise,
    };
  }

  /// READ-ONLY view: show best distance if cardio, best volume if strength
  Widget _buildReadOnlyView(AsyncSnapshot<Map<String, dynamic>> snapshot) {
    final data = widget.exercise.data() as Map<String, dynamic>? ?? {};
    final exerciseName = data["name"] ?? "";
    final exerciseCategory = data["category"] ?? "";
    final exerciseMainBodyPart =
        data["mainBodyPart"] ?? data["bodyPart"] ?? "Other";
    final exerciseSubBodyPart =
        data["subBodyPart"] ?? data["subcategory"] ?? "";
    final exerciseDescription = data["description"] ?? "";
    final exerciseNotes = data["notes"] ?? "";

    final bestEntry = snapshot.data?['bestEntry'] as Map<String, dynamic>?;
    final recent = snapshot.data?['recent'] as List<Map<String, dynamic>>? ?? [];
    final isCardio = snapshot.data?['isCardio'] == true;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic info
          Text(
            "Name: $exerciseName",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text("Category: $exerciseCategory",
              style: Theme.of(context).textTheme.bodyMedium),
          Text("Main Body Part: $exerciseMainBodyPart",
              style: Theme.of(context).textTheme.bodyMedium),
          if (exerciseSubBodyPart.isNotEmpty)
            Text("Specific Muscle Group: $exerciseSubBodyPart",
                style: Theme.of(context).textTheme.bodyMedium),
          if (exerciseDescription.isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Description: $exerciseDescription",
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (exerciseNotes.isNotEmpty) ...[
            SizedBox(height: 8),
            Text("Notes: $exerciseNotes",
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          SizedBox(height: 20),

          // Personal Best
          Text(
            "Personal Best",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (bestEntry == null)
            Text("No data found.", style: Theme.of(context).textTheme.bodyMedium)
          else
            Card(
              color: Theme.of(context).cardColor,
              child: ListTile(
                leading: Icon(Icons.star, color: Colors.amber),
                title: Text(
                  "Date: ${bestEntry['date'].toLocal().toString().split('.')[0]}",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: isCardio
                    ? _buildCardioBestSubtitle(bestEntry)
                    : _buildStrengthBestSubtitle(bestEntry),
              ),
            ),

          SizedBox(height: 20),

          // Recent History
          Text(
            "Recent History",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (recent.isEmpty)
            Text("No recent data found.",
                style: Theme.of(context).textTheme.bodyMedium)
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

  /// Show the single "best" cardio set (highest distance, tie -> shortest duration).
  Widget _buildCardioBestSubtitle(Map<String, dynamic> bestEntry) {
    final sets = bestEntry['sets'] ?? [];
    // We expect only one set here, but let's handle multiple gracefully.
    return Consumer<UnitProvider>(
      builder: (context, unitProvider, child) {
        List<String> lines = [];
        for (var s in sets) {
          double dist = double.tryParse(s['distance']?.toString() ?? '') ?? 0.0;
          int dur = 0;
          if (s['duration'] != null) {
            dur = (s['duration'] is int)
                ? s['duration']
                : int.tryParse(s['duration'].toString()) ?? 0;
          }
          if (unitProvider.useMetric) {
            dist = UnitConverter.milesToKm(dist);
          }
          lines.add(
              "Distance: ${dist.toStringAsFixed(2)} ${unitProvider.useMetric ? 'km' : 'mi'} | Duration: ${_formatDuration(dur)}");
        }
        return Text(lines.join("\n"),
            style: Theme.of(context).textTheme.bodySmall);
      },
    );
  }

  /// Show the single "best" strength workout (highest total volume).
  Widget _buildStrengthBestSubtitle(Map<String, dynamic> bestEntry) {
    final sets = bestEntry['sets'] ?? [];
    double volume = bestEntry['volume'] ?? 0.0;

    return Consumer<UnitProvider>(
      builder: (context, unitProvider, child) {
        double displayVolume = volume;
        if (unitProvider.useMetric) {
          displayVolume = UnitConverter.lbsToKg(displayVolume);
        }
        String volumeLine = "Total Volume: ${displayVolume.toStringAsFixed(1)}";
        String setDetails = sets.asMap().entries.map((e) {
          final idx = e.key + 1;
          final set = e.value as Map<String, dynamic>;
          List<String> parts = ["Set $idx:"];
          if (set.containsKey('weight') && set.containsKey('reps')) {
            double weightVal = 0.0;
            if (set['weight'] is int) {
              weightVal = (set['weight'] as int).toDouble();
            } else if (set['weight'] is double) {
              weightVal = set['weight'];
            } else {
              weightVal = double.tryParse(set['weight'].toString()) ?? 0.0;
            }
            if (unitProvider.useMetric) {
              weightVal = UnitConverter.lbsToKg(weightVal);
            }
            int repsVal = 0;
            if (set['reps'] is int) {
              repsVal = set['reps'];
            } else {
              repsVal = int.tryParse(set['reps'].toString()) ?? 0;
            }
            parts.add("${weightVal.toStringAsFixed(1)} ${unitProvider.useMetric ? 'kg' : 'lbs'} x $repsVal reps");
          }
          return parts.join(" ");
        }).join("\n");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(volumeLine, style: Theme.of(context).textTheme.bodySmall),
            if (setDetails.isNotEmpty)
              Text(setDetails, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }

  /// Convert seconds to "h m s" format
  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final buffer = StringBuffer();
    if (hours > 0) buffer.write('${hours}h ');
    if (minutes > 0) buffer.write('${minutes}m ');
    if (seconds > 0) buffer.write('${seconds}s');
    return buffer.isEmpty ? '0s' : buffer.toString().trim();
  }

  /// For the "Recent History" items, we show sets (weight, reps, distance, duration, etc.).
  Widget _buildEntrySubtitle(Map<String, dynamic> entry) {
    List sets = entry['sets'] ?? [];

    return Consumer<UnitProvider>(
      builder: (context, unitProvider, child) {
        String setDetails = sets.asMap().entries.map((e) {
          final setNum = e.key + 1;
          final set = e.value as Map<String, dynamic>;

          List<String> parts = ["Set $setNum:"];

          // Duration
          if (set.containsKey('duration')) {
            int durationSec = 0;
            var rawDuration = set['duration'];
            if (rawDuration is int) {
              durationSec = rawDuration;
            } else {
              durationSec = int.tryParse(rawDuration.toString()) ?? 0;
            }
            parts.add("Duration: ${_formatDuration(durationSec)}");
          }

          // Distance
          if (set.containsKey('distance')) {
            double distVal =
                double.tryParse(set['distance']?.toString() ?? '') ?? 0.0;
            if (unitProvider.useMetric) {
              distVal = UnitConverter.milesToKm(distVal);
              parts.add("Distance: ${distVal.toStringAsFixed(2)} km");
            } else {
              parts.add("Distance: ${distVal.toStringAsFixed(2)} mi");
            }
          }

          // Weight/Reps
          if (set.containsKey('weight') && set.containsKey('reps')) {
            double weightVal = 0.0;
            var rawWeight = set['weight'];
            if (rawWeight is int) {
              weightVal = rawWeight.toDouble();
            } else if (rawWeight is double) {
              weightVal = rawWeight;
            } else {
              weightVal = double.tryParse(rawWeight.toString()) ?? 0.0;
            }
            if (unitProvider.useMetric) {
              weightVal = UnitConverter.lbsToKg(weightVal);
            }
            String unitLabel = unitProvider.useMetric ? "kg" : "lbs";

            int repsVal = 0;
            var rawReps = set['reps'];
            if (rawReps is int) {
              repsVal = rawReps;
            } else {
              repsVal = int.tryParse(rawReps.toString()) ?? 0;
            }
            parts.add("${weightVal.toStringAsFixed(1)} $unitLabel x $repsVal reps");
          } else if (set.containsKey('reps') && !set.containsKey('weight')) {
            // Reps only
            var rawReps = set['reps'];
            int repsVal =
            (rawReps is int) ? rawReps : int.tryParse(rawReps.toString()) ?? 0;
            parts.add("Reps: $repsVal");
          }

          return parts.join(" | ");
        }).join("\n");

        return Text(setDetails, style: Theme.of(context).textTheme.bodySmall);
      },
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
              labelStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Category
          DropdownButtonFormField(
            value: selectedCategory,
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            style: Theme.of(context).textTheme.bodyMedium,
            items: categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child:
                Text(category, style: Theme.of(context).textTheme.bodyMedium),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value.toString();
                // If user changes category to "Cardio Exercises," switch logic
                isCardioExercise = (selectedCategory == "Cardio Exercises");
              });
            },
            decoration: InputDecoration(
              labelText: "Category",
              labelStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
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
                child: Text(
                  mainPart,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
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
              labelStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
          ),
          SizedBox(height: 8),

          // Sub Body Part
          if (selectedMainBodyPart != null &&
              bodyPartHierarchy[selectedMainBodyPart]!.isNotEmpty)
            DropdownButtonFormField<String>(
              value: bodyPartHierarchy[selectedMainBodyPart!]!
                  .contains(selectedSubBodyPart)
                  ? selectedSubBodyPart
                  : null,
              dropdownColor: Theme.of(context).scaffoldBackgroundColor,
              style: Theme.of(context).textTheme.bodyMedium,
              items: bodyPartHierarchy[selectedMainBodyPart!]!.map((subPart) {
                return DropdownMenuItem(
                  value: subPart,
                  child: Text(subPart,
                      style: Theme.of(context).textTheme.bodyMedium),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubBodyPart = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Specific Muscle Group",
                labelStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).hintColor),
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
              labelStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
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
              labelStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor),
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
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            iconTheme: Theme.of(context).appBarTheme.iconTheme,
            title: Text(
              "Exercise Details",
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
            actions: [
              // Edit / Save icon
              IconButton(
                icon: Icon(
                  _isEditing ? Icons.check : Icons.edit,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  if (_isEditing) {
                    _updateExercise();
                  }
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
              ),
              // Delete icon
              IconButton(
                icon:
                Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                onPressed: _deleteExercise,
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          )
              : _isEditing
              ? _buildEditView()
              : _buildReadOnlyView(snapshot),
        );
      },
    );
  }
}
