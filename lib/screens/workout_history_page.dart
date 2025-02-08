import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class workout_history_page extends StatefulWidget {
  @override
  _WorkoutHistoryPageState createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<workout_history_page> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  String searchQuery = "";
  DateTime? startDate;
  DateTime? endDate;
  String sortOption = "Newest to Oldest";
  Timer? _debounce;

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end.add(Duration(days: 1)).subtract(Duration(seconds: 1)); // Ensure full day range
      });
    }
  }

  Stream<QuerySnapshot> getWorkouts() {
    Query query = _firestore.collection('workouts').where('userId', isEqualTo: user?.uid);

    if (startDate != null && endDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));
    }

    if (sortOption == "Alphabetical Order") {
      query = query.orderBy('name');
    } else {
      query = query.orderBy('timestamp', descending: sortOption == "Newest to Oldest");
    }

    if (searchQuery.isNotEmpty) {
      query = query.where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThanOrEqualTo: searchQuery + '\uf8ff');
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout History'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(10.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: DropdownButton<String>(
              isExpanded: true,
              value: sortOption,
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getWorkouts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final workouts = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: workouts.length,
                  itemBuilder: (context, index) {
                    var workout = workouts[index].data() as Map<String, dynamic>;
                    return Card(
                      margin: EdgeInsets.all(8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: ListTile(
                        title: Text(workout['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat.yMMMd().format((workout['timestamp'] as Timestamp).toDate())),
                        trailing: Icon(Icons.fitness_center),
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
