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
  final TextEditingController _searchController = TextEditingController();
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

  /// Applies search & filters
  List<QueryDocumentSnapshot<Object?>> applyFilters(List<QueryDocumentSnapshot<Object?>> exercises) {
    return exercises.where((exercise) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      String name = data['name']?.toString().toLowerCase() ?? "";
      String category = data['category']?.toString() ?? "";
      String bodyPart = data['bodyPart']?.toString() ?? "";

      bool matchesSearch = name.contains(searchQuery.toLowerCase());
      bool matchesCategory = selectedCategory == null || category == selectedCategory;
      bool matchesBodyPart = selectedBodyPart == null ||
          bodyPart == selectedBodyPart ||
          (bodyPartHierarchy[selectedBodyPart]?.contains(bodyPart) ?? false);

      return matchesSearch && matchesCategory && matchesBodyPart;
    }).toList();
  }

  /// Groups exercises by selected sort option
  Map<String, List<QueryDocumentSnapshot<Object?>>> groupByField(
      List<QueryDocumentSnapshot<Object?>> exercises,
      String field,
      ) {
    Map<String, List<QueryDocumentSnapshot<Object?>>> grouped = {};
    for (var exercise in exercises) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      String key = data[field]?.toString().trim() ?? "Uncategorized";

      // For alphabetical grouping, use the first letter of the name
      if (field == "name" && key.isNotEmpty) {
        key = key[0].toUpperCase();
      }
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(exercise);
    }
    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  /// Navigates to Create Exercise Page
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          title: Text("Exercises", style: Theme.of(context).appBarTheme.titleTextStyle),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Text(
            "You need to log in to view your exercises.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text("Exercises", style: Theme.of(context).appBarTheme.titleTextStyle),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          /// Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search Exercises",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
                prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: const OutlineInputBorder(),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),

          /// Sort By (Full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: selectedSort,
              items: sortOptions.map((sort) {
                return DropdownMenuItem(
                  value: sort,
                  child: Text(sort, style: Theme.of(context).textTheme.bodyMedium),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedSort = value!;
                });
              },
              decoration: InputDecoration(
                labelText: "Sort By",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),

          /// Category (Full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: DropdownButtonFormField<String>(
              value: selectedCategory,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text("All Categories", style: Theme.of(context).textTheme.bodyMedium),
                ),
                ...categories.map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category, style: Theme.of(context).textTheme.bodyMedium),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
              decoration: InputDecoration(
                labelText: "Category",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),

          /// Body Part (Full width)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: selectedBodyPart,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text("All Body Parts", style: Theme.of(context).textTheme.bodyMedium),
                ),
                ...bodyPartHierarchy.entries.expand((entry) {
                  String parent = entry.key;
                  List<String> subcategories = entry.value;
                  return [
                    DropdownMenuItem(
                      value: parent,
                      child: Text(
                        parent,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...subcategories.map((subcategory) => DropdownMenuItem(
                      value: subcategory,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: Text(
                          "— $subcategory",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
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
              decoration: InputDecoration(
                labelText: "Body Part",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),

          /// Exercise List
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
                  return Center(
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                  );
                }

                var exercises = applyFilters(snapshot.data!.docs);
                if (exercises.isEmpty) {
                  return Center(
                    child: Text("No exercises found.", style: Theme.of(context).textTheme.bodyMedium),
                  );
                }

                Map<String, List<QueryDocumentSnapshot<Object?>>> groupedExercises = groupByField(
                  exercises,
                  selectedSort == "Alphabetical"
                      ? "name"
                      : selectedSort == "Body Part"
                      ? "bodyPart"
                      : "category",
                );

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
                              color: Theme.of(context).cardColor,
                            ),
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              groupKey,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...groupedExercises[groupKey]!.map((exercise) {
                            var data = exercise.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(
                                data['name'],
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              subtitle: Text(
                                "${data['category']} - ${data['bodyPart']}",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
