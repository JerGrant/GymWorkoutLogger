import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exercise_detail_page.dart';

class ExercisePage extends StatefulWidget {
  @override
  _ExercisePageState createState() => _ExercisePageState();
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
    "Barbell", "Dumbbell", "Cables", "Machine", "Other", "Weighted Bodyweight",
    "Assisted Body", "Laps", "Reps", "Cardio Exercises", "Duration", "Kettlebell",
    "Plyometrics", "Resistance Bands", "Isometrics", "Stretching & Mobility"
  ];

  List<QueryDocumentSnapshot<Object?>> applyFilters(List<QueryDocumentSnapshot<Object?>> exercises) {
    return exercises.where((exercise) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      bool matchesSearch = data['name']?.toString().toLowerCase().contains(searchQuery) ?? false;

      bool matchesBodyPart = true;
      if (selectedBodyPart != null) {
        if (bodyPartHierarchy.containsKey(selectedBodyPart!)) {
          List<String> subParts = bodyPartHierarchy[selectedBodyPart!] ?? [];
          matchesBodyPart = subParts.contains(data['bodyPart']) || data['bodyPart'] == selectedBodyPart;
        } else {
          matchesBodyPart = data['bodyPart'] == selectedBodyPart;
        }
      }

      bool matchesCategory = selectedCategory == null || data['category'] == selectedCategory;

      return matchesSearch && matchesBodyPart && matchesCategory;
    }).toList();
  }

  Map<String, List<QueryDocumentSnapshot<Object?>>> groupByField(
      List<QueryDocumentSnapshot<Object?>> exercises, String field) {
    Map<String, List<QueryDocumentSnapshot<Object?>>> grouped = {};

    if (field == "bodyPart") {
      bodyPartHierarchy.forEach((parent, subcategories) {
        grouped[parent] = [];
        for (var subcategory in subcategories) {
          grouped[subcategory] = [];
        }
      });
    }

    for (var exercise in exercises) {
      var data = exercise.data() as Map<String, dynamic>? ?? {};
      String key = data[field]?.toString() ?? "Unknown";

      if (field == "name" && key.isNotEmpty) {
        key = key[0].toUpperCase();
      }

      if (field == "bodyPart") {
        bodyPartHierarchy.forEach((parent, subcategories) {
          if (key == parent || subcategories.contains(key)) {
            grouped[parent]!.add(exercise);
          }
        });
      } else {
        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(exercise);
      }
    }

    if (field == "bodyPart") {
      grouped.removeWhere((key, value) =>
      value.isEmpty &&
          bodyPartHierarchy.containsKey(key) &&
          bodyPartHierarchy[key]!.every((sub) => grouped[sub]!.isEmpty));
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Exercises"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: "Search Exercises",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSort,
                    items: sortOptions.map((sort) => DropdownMenuItem(
                      value: sort,
                      child: Text(sort),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSort = value!;
                      });
                    },
                    decoration: InputDecoration(labelText: "Sort By"),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: [
                      DropdownMenuItem(value: null, child: Text("All Categories")),
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
                      DropdownMenuItem(value: null, child: Text("All Body Parts")),
                      ...bodyPartHierarchy.entries.expand((entry) {
                        String parent = entry.key;
                        List<String> subcategories = entry.value;
                        return [
                          DropdownMenuItem(
                            value: parent,
                            child: Text(
                              parent,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...subcategories.map((subcategory) => DropdownMenuItem(
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
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var exercises = applyFilters(snapshot.data!.docs);

                Map<String, List<QueryDocumentSnapshot<Object?>>> groupedExercises;
                if (selectedSort == "Alphabetical") {
                  groupedExercises = groupByField(exercises, "name");
                } else if (selectedSort == "Body Part") {
                  groupedExercises = groupByField(exercises, "bodyPart");
                } else {
                  groupedExercises = groupByField(exercises, "category");
                }

                var sortedKeys = groupedExercises.keys.toList()..sort();

                return ListView.builder(
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, groupIndex) {
                    String groupKey = sortedKeys[groupIndex];
                    List<QueryDocumentSnapshot<Object?>> groupExercises = groupedExercises[groupKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (groupExercises.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              groupKey,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ...groupExercises.map((exercise) {
                          var data = exercise.data() as Map<String, dynamic>? ?? {};
                          return ListTile(
                            title: Text(data['name'] ?? 'Unknown Exercise'),
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddExercisePage(categories: categories)),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddExercisePage extends StatefulWidget {
  final List<String> categories;

  AddExercisePage({required this.categories});

  @override
  _AddExercisePageState createState() => _AddExercisePageState();
}

class _AddExercisePageState extends State<AddExercisePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String selectedCategory = "Barbell";
  String selectedBodyPart = "Chest";

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Add Exercise")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: "Exercise Name"),
            ),
            DropdownButtonFormField(
              value: selectedCategory,
              items: widget.categories.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value.toString();
                });
              },
              decoration: InputDecoration(labelText: "Category"),
            ),
            DropdownButtonFormField(
              value: selectedBodyPart,
              items: [
                DropdownMenuItem(value: null, child: Text("All Body Parts")),
                ...bodyPartHierarchy.entries.expand((entry) {
                  String parent = entry.key;
                  List<String> subcategories = entry.value;
                  return [
                    DropdownMenuItem(
                      value: parent,
                      child: Text(
                        parent,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...subcategories.map((subcategory) => DropdownMenuItem(
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
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection('exercises').add({
                  'name': _nameController.text,
                  'category': selectedCategory,
                  'bodyPart': selectedBodyPart,
                  'description': _descriptionController.text.trim(),
                });
                Navigator.pop(context);
              },
              child: Text("Add Exercise"),
            ),
          ],
        ),
      ),
    );
  }
}