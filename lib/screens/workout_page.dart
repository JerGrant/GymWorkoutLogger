import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'workout_session_page.dart';
import 'workout_history_page.dart';

class WorkoutPage extends StatefulWidget {
  @override
  _WorkoutPageState createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  int totalWorkouts = 0;
  int workoutsThisMonth = 0;

  List<BarChartGroupData> weeklyBarGroups = [];
  List<DateTime> sortedWeekDates = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkoutStats();
    _fetchWeeklyWorkouts();
  }

  // ----------------------------------------------------
  // 1) Basic Stats
  // ----------------------------------------------------
  Future<void> _fetchWorkoutStats() async {
    if (user == null) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    QuerySnapshot workoutSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: user!.uid)
        .get();

    int total = workoutSnapshot.docs.length;
    int thisMonth = workoutSnapshot.docs.where((doc) {
      Timestamp timestamp = doc['timestamp'];
      DateTime workoutDate = timestamp.toDate();
      return workoutDate.isAfter(startOfMonth);
    }).length;

    setState(() {
      totalWorkouts = total;
      workoutsThisMonth = thisMonth;
    });
  }

  // ----------------------------------------------------
  // 2) Weekly Bar Chart Data
  // ----------------------------------------------------
  Future<void> _fetchWeeklyWorkouts() async {
    if (user == null) return;

    final snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: user!.uid)
        .orderBy('timestamp', descending: false)
        .get();

    Map<DateTime, int> weeklyCounts = {};

    for (var doc in snapshot.docs) {
      final Timestamp ts = doc['timestamp'];
      final DateTime date = ts.toDate();

      // Convert the date to Monday of that week
      final DateTime monday = _mondayOfWeek(date);

      weeklyCounts[monday] = (weeklyCounts[monday] ?? 0) + 1;
    }

    final allMondays = weeklyCounts.keys.toList()..sort();

    List<BarChartGroupData> groups = [];
    for (int i = 0; i < allMondays.length; i++) {
      final mondayDate = allMondays[i];
      final count = weeklyCounts[mondayDate] ?? 0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.purple,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    setState(() {
      sortedWeekDates = allMondays;
      weeklyBarGroups = groups;
    });
  }

  /// Returns the Monday of the week that [date] is in.
  DateTime _mondayOfWeek(DateTime date) {
    int delta = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: delta));
  }

  // ----------------------------------------------------
  // 3) UI Helpers
  // ----------------------------------------------------
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return DateFormat('MMM d, h:mm a').format(date);
  }

  // ----------------------------------------------------
  // 4) Widget Build
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Workout Log'),
            IconButton(
              icon: Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => workout_history_page()),
                );
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStartWorkoutButton(context),
            SizedBox(height: 20),
            _buildWorkoutStats(),
            SizedBox(height: 20),
            _buildWeeklyChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildStartWorkoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WorkoutSessionPage()),
          );
        },
        child: Text('Start a Workout', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildWorkoutStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workout Stats',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard('Total Workouts', totalWorkouts),
            _buildStatCard('Workouts This Month', workoutsThisMonth),
          ],
        ),
      ],
    );
  }

  /// Ensure each stat card is the same width, and text doesn't wrap.
  Widget _buildStatCard(String title, int count) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Slightly smaller font, single line, ellipsis if it doesn't fit
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 5),
            Text(
              '$count',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workouts per week',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Container(
          height: 200,
          child: BarChart(
            BarChartData(
              minY: 0,
              barGroups: weeklyBarGroups,
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 1),
                  left: BorderSide(color: Colors.grey, width: 1),
                  right: BorderSide(color: Colors.transparent),
                  top: BorderSide(color: Colors.transparent),
                ),
              ),
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= sortedWeekDates.length) {
                        return SizedBox.shrink();
                      }
                      final date = sortedWeekDates[index];
                      final label = DateFormat('M/d').format(date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(label, style: TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
