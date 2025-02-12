import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'workout_session_page.dart';
import 'workout_history_page.dart';
import 'package:fl_chart/fl_chart.dart';

class WorkoutPage extends StatefulWidget {
  @override
  _WorkoutPageState createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  int totalWorkouts = 0;
  int workoutsThisMonth = 0;

  @override
  void initState() {
    super.initState();
    _fetchWorkoutStats();
  }

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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return DateFormat('MMM d, h:mm a').format(date);
  }

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
            _buildGraphsAndInsights(),
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
        Text('Workout Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  Widget _buildStatCard(String title, int count) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            SizedBox(height: 5),
            Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphsAndInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workout Progress', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Container(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, 2),
                    FlSpot(1, 4),
                    FlSpot(2, 6),
                    FlSpot(3, 8),
                    FlSpot(4, 7),
                  ],
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
