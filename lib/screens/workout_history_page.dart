import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'calendar_filter_page.dart';
import 'workout_history_detail_page.dart';

class WorkoutHistoryPage extends StatefulWidget {
  @override
  _WorkoutHistoryPageState createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  String searchQuery = "";
  DateTime? startDate;
  DateTime? endDate;
  String sortOption = "Newest to Oldest";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    startDate = null; // No default date filter
    endDate = null;
  }

  void _openCalendarFilter() async {
    final DateTimeRange? picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CalendarFilterPage(),
      ),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  Stream<QuerySnapshot> getWorkouts() {
    Query query = _firestore.collection('workouts').where('userId', isEqualTo: user?.uid);

    // If user has selected a date range, apply it.
    if (startDate != null && endDate != null) {
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    }

    // Handle sort options.
    if (sortOption == "Alphabetical Order") {
      query = query.orderBy('name');
    } else if (sortOption == "Oldest to Newest") {
      query = query.orderBy('timestamp', descending: false);
    } else {
      // Default to "Newest to Oldest"
      query = query.orderBy('timestamp', descending: true);
    }

    // If there's a search query, filter by name (case-insensitive).
    if (searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _capitalize(searchQuery))
          .where('name', isLessThanOrEqualTo: _capitalize(searchQuery) + '\uf8ff');
    }

    return query.snapshots();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
      setState(() {
        searchQuery = value.trim();
      });
    });
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Updated
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // Updated
        surfaceTintColor: Colors.transparent,
        iconTheme: Theme.of(context).appBarTheme.iconTheme, // Updated
        title: Text(
          'Workout History',
          style: Theme.of(context).appBarTheme.titleTextStyle, // Updated
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary), // Updated
            onPressed: _openCalendarFilter, // Open calendar filter
          )
        ],
      ),
      body: Column(
        children: [
          if (startDate != null && endDate != null)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                "Showing Workouts: ${DateFormat.yMMMd().format(startDate!)} - ${DateFormat.yMMMd().format(endDate!)}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold), // Updated
              ),
            ),
          // Sorting dropdown
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: DropdownButton<String>(
              isExpanded: true,
              value: sortOption,
              dropdownColor: Theme.of(context).scaffoldBackgroundColor, // Updated
              style: Theme.of(context).textTheme.bodyMedium, // Updated
              iconEnabledColor: Theme.of(context).iconTheme.color, // Updated
              onChanged: (String? newValue) {
                setState(() {
                  sortOption = newValue!;
                });
              },
              items: ["Newest to Oldest", "Oldest to Newest", "Alphabetical Order"]
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
          // Search field
          Padding(
            padding: EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search by name',
                labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor), // Updated
                prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color?.withOpacity(0.7)), // Updated
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor, // Updated
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor), // Updated
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodyMedium?.color), // Updated
              onChanged: _onSearchChanged,
            ),
          ),
          // Workout List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getWorkouts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)); // Updated
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No workouts found.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final workout = doc.data() as Map<String, dynamic>;
                    final workoutId = doc.id; // Firestore document ID

                    // Read the 'favorited' field
                    final isFavorited = workout['favorited'] == true;

                    // Safely handle the timestamp conversion
                    final ts = workout['timestamp'];
                    String subtitleText;
                    if (ts is Timestamp) {
                      subtitleText = DateFormat.yMMMd().format(ts.toDate());
                    } else {
                      subtitleText = "No date available";
                    }

                    return Card(
                      color: Theme.of(context).cardColor, // Updated
                      margin: EdgeInsets.all(8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: ListTile(
                        title: Text(
                          workout['name'] ?? 'Unnamed Workout',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          subtitleText,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary), // Updated
                            SizedBox(width: 8),
                            Icon(
                              isFavorited ? Icons.star : Icons.star_border,
                              color: isFavorited ? Colors.amber : Colors.grey, // Keeping as is
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutHistoryDetailPage(
                                workout: workout,
                                workoutId: workoutId,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
