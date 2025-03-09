import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'workout_history_detail_page.dart';

class CalendarFilterPage extends StatefulWidget {
  @override
  _CalendarFilterPageState createState() => _CalendarFilterPageState();
}

class _CalendarFilterPageState extends State<CalendarFilterPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  DateTime? startDate;
  DateTime? endDate;
  DateTime focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  @override
  void initState() {
    super.initState();
    startDate = DateTime.now();
    endDate = DateTime.now();
  }

  Stream<QuerySnapshot> getWorkouts() {
    if (startDate == null || endDate == null) return Stream.empty();

    // Ensure timestamps cover the full day (00:00:00 - 23:59:59)
    DateTime adjustedStart = DateTime(startDate!.year, startDate!.month, startDate!.day, 0, 0, 0);
    DateTime adjustedEnd = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);

    print("Fetching workouts from ${adjustedStart.toUtc()} to ${adjustedEnd.toUtc()}"); // Debugging

    Query query = _firestore
        .collection('workouts')
        .where('userId', isEqualTo: user?.uid)
        .orderBy('timestamp') // Firestore requires ordering before range filtering
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(adjustedStart))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(adjustedEnd));

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Updated from Color(0xFF000015)
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // Updated from Color(0xFF000015)
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Workout Calendar",
          style: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(fontSize: 16, fontWeight: FontWeight.bold), // Updated
        ),
      ),
      body: Column(
        children: [
          // Calendar Widget
          TableCalendar(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: focusedDay,
            calendarFormat: _calendarFormat,
            rangeSelectionMode: _rangeSelectionMode,
            rangeStartDay: startDate,
            rangeEndDay: endDate,
            onRangeSelected: (start, end, focused) {
              setState(() {
                startDate = start;
                endDate = end ?? start;
                focusedDay = focused;
              });
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).iconTheme.color),
              rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: Theme.of(context).textTheme.bodyMedium ?? TextStyle(),
              weekendTextStyle: Theme.of(context).textTheme.bodyMedium ?? TextStyle(),
              outsideTextStyle: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(color: Theme.of(context).hintColor),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Selected Date Range Display
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              startDate != null && endDate != null
                  ? "Showing Workouts: ${DateFormat.yMMMd().format(startDate!)} - ${DateFormat.yMMMd().format(endDate!)}"
                  : "Select a date range",
              style: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          // Workout List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getWorkouts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No workouts found in this date range.",
                      style: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final workout = doc.data() as Map<String, dynamic>;
                    final workoutId = doc.id;
                    return Card(
                      color: Theme.of(context).cardColor,
                      margin: EdgeInsets.all(8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: ListTile(
                        title: Text(
                          workout['name'] ?? 'Unnamed Workout',
                          style: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat.yMMMd().format(
                            (workout['timestamp'] as Timestamp).toDate(),
                          ),
                          style: (Theme.of(context).textTheme.bodyMedium ?? TextStyle()).copyWith(color: Theme.of(context).hintColor),
                        ),
                        trailing: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary),
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
