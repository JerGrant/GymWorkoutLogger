import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'exercise_detail_page.dart';
import 'create_exercise_page.dart';

class ExercisePage extends StatefulWidget {
  @override
  _ExercisePageState createState() => _ExercisePageState();
}

class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}


class _ExercisePageState extends State<ExercisePage> {
  TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String selectedSort = "Alphabetical";
  String? selectedCategory;
  String? selectedBodyPart;

  final List<String> sortOptions = ["Alphabetical", "Body Part", "Category"];

  final Map<String, List<String>> bodyPartHierarchy = {
    "Shoulders": ["Front Delts", "Side Delts", "Rear Delts"],
    "Chest": [],
    "Arms": ["Biceps", "Triceps", "Forearms"],
    "Back": ["Lats", "Traps", "Lower Back"],
    "Core": ["Upper Abs", "Lower Abs", "Obliques"],
    "Legs": ["Quads", "Hamstrings", "Calves", "Glutes"],
    "Full Body": [],
    "Cardio": [],
    "Swimming": [],
    "Other": [],
  };

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

  /// **Applies Search & Filters**
  List<QueryDocumentSnapshot<Object?>> applyFilters(
      List<QueryDocumentSnapshot<Object?>> exercises) {
    return exercises.where((exercise) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};

      String name = data['name']?.toString().toLowerCase() ?? "";
      String category = data['category']?.toString() ?? "";
      String bodyPart = data['bodyPart']?.toString() ?? "";

      bool matchesSearch = name.contains(searchQuery.toLowerCase());
      bool matchesCategory =
          selectedCategory == null || category == selectedCategory;
      bool matchesBodyPart = selectedBodyPart == null ||
          bodyPart == selectedBodyPart ||
          (bodyPartHierarchy[selectedBodyPart]?.contains(bodyPart) ?? false);

      return matchesSearch && matchesCategory && matchesBodyPart;
    }).toList();
  }

  /// **Groups Exercises by Selected Sort Option**
  Map<String, List<QueryDocumentSnapshot<Object?>>>
  groupByField(List<QueryDocumentSnapshot<Object?>> exercises, String field) {
    Map<String, List<QueryDocumentSnapshot<Object?>>> grouped = {};

    for (var exercise in exercises) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};

      String key = data[field]?.toString().trim() ?? "Uncategorized"; // More meaningful default

      if (field == "name" && key.isNotEmpty) {
        key = key[0].toUpperCase(); // Sort Alphabetically
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(exercise);
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  /// **Navigates to Create Exercise Page**
  void _navigateToCreateExercisePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateExercisePage()),
    );

    if (result != null) {
      setState(() {}); // Refresh after adding a new exercise
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Color(0xFF000015), // Set background color
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Color(0xFF000015), // Ensures background stays fixed
          elevation: 0, // Prevents shadow/lightening effect when scrolling
          title: Text("Exercises", style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false,
        ),
        body: Center(child: Text("You need to log in to view your exercises.")),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF000015), // Set background color
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Color(0xFF000015), // Ensures background stays fixed
        elevation: 0, // Prevents shadow/lightening effect when scrolling
        title: Text("Exercises", style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          /// **Search Bar**
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search Exercises",
                labelStyle: TextStyle(color: Colors.white70), // Label text color
                prefixIcon: Icon(Icons.search, color: Colors.white70), // Search icon color
                filled: true,
                fillColor: Color(0xFF000015), // Slightly lighter dark blue for contrast
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: Colors.white), // Ensure input text is visible
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),

          /// **Sorting Dropdown**
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: selectedSort,
              items: sortOptions
                  .map((sort) => DropdownMenuItem(
                value: sort,
                child: Text(sort),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedSort = value!;
                });
              },
              decoration: InputDecoration(labelText: "Sort By"),
            ),
          ),

          /// **Category & Body Part Filters**
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text("All Categories")),
                      ...categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                    decoration: InputDecoration(labelText: "Category"),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedBodyPart,
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text("All Body Parts")),
                      ...bodyPartHierarchy.entries.expand((entry) {
                        String parent = entry.key;
                        List<String> subcategories = entry.value;
                        return [
                          DropdownMenuItem(
                            value: parent,
                            child: Text(parent,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ...subcategories.map((subcategory) =>
                              DropdownMenuItem(
                                value: subcategory,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Text("— $subcategory"),
                                ),
                              )),
                        ];
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedBodyPart = value;
                      });
                    },
                    decoration: InputDecoration(labelText: "Body Part"),
                  ),
                ),
              ],
            ),
          ),

          /// **Exercise List**
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('exercises')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var exercises = applyFilters(snapshot.data!.docs);
                if (exercises.isEmpty) {
                  return Center(child: Text("No exercises found."));
                }

                Map<String, List<QueryDocumentSnapshot<Object?>>> groupedExercises =
                groupByField(
                    exercises,
                    selectedSort == "Alphabetical"
                        ? "name"
                        : selectedSort == "Body Part"
                        ? "bodyPart"
                        : "category");

                return ScrollConfiguration(
                  behavior: NoGlowScrollBehavior(),
                  child: ListView.builder(
                    itemCount: groupedExercises.keys.length,
                    itemBuilder: (context, index) {
                      String groupKey = groupedExercises.keys.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Color(0xFF000015), // Force the fixed dark color
                            ),
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              groupedExercises.keys.elementAt(index),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          ...groupedExercises[groupKey]!.map((exercise) {
                            var data = exercise.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['name']),
                              subtitle: Text("${data['category']} - ${data['bodyPart']}"),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExerciseDetailsPage(exercise: exercise),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateExercisePage,
        backgroundColor: Color(0xFF007AFF), // Maintain contrast
        child: Icon(Icons.add, color: Colors.white), // Ensure icon is visible
      ),
    );
  }
}
