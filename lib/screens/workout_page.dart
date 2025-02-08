import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'workout_session_page.dart';
import 'package:fl_chart/fl_chart.dart';

class WorkoutPage extends StatefulWidget {
  @override
  _WorkoutPageState createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Workout Log')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStartWorkoutButton(context),
            SizedBox(height: 20),
            _buildWorkoutHistory(),
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

  Widget _buildWorkoutHistory() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('workouts')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final workouts = snapshot.data!.docs;
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              return ListTile(
                title: Text(workout['name']),
                subtitle: Text(
                  "Logged at ${_formatTimestamp(workout['timestamp'])} | Duration: ${workout['duration']} mins",
                ),
              );
            },
          );
        },
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
