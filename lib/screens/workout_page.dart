import 'dart:math' as math; // For math.max
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gymworkoutlogger/screens/workout_history_page.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'workout_session_page.dart';
import 'favorite_workouts_page.dart';

class WorkoutPage extends StatefulWidget {
  @override
  _WorkoutPageState createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  // Basic stats
  int totalWorkouts = 0;
  int workoutsThisMonth = 0;
  int totalDuration = 0; // in minutes
  double avgDuration = 0; // in minutes

  // Streaks (session-based, not deduplicating by day)
  int currentStreak = 0; // chain of consecutive sessions including the latest
  int longestStreak = 0; // max chain across entire history

  // Expected workouts per week => allowed rest days = 7 - expectedWorkoutDays
  int expectedWorkoutDays = 5;

  // Bar chart data
  List<BarChartGroupData> weeklyBarGroups = [];
  List<DateTime> sortedWeekDates = [];

  // Track the maximum Y value for the chart
  double maxYForChart = 0;

  @override
  void initState() {
    super.initState();
    _fetchWorkoutStats();
    _fetchWeeklyWorkouts();
  }

  // --------------------------
  // 1) Parsing & Streak Logic
  // --------------------------

  /// Safely parse 'duration' from Firestore. Could be int or double.
  int parseDuration(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    return 0;
  }

  /// Fetch workouts & calculate stats (session-based streaks).
  Future<void> _fetchWorkoutStats() async {
    if (user == null) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    QuerySnapshot snapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: user!.uid)
        .orderBy('timestamp', descending: false)
        .get();

    int total = snapshot.docs.length;
    int thisMonth = 0;

    // We'll accumulate durations in MINUTES now
    int durationSumInMinutes = 0;

    List<DateTime> sessions = [];

    for (var doc in snapshot.docs) {
      final Timestamp ts = doc['timestamp'];
      final DateTime dt = ts.toDate();

      // 1) Count if in this month
      if (dt.isAfter(startOfMonth)) {
        thisMonth++;
      }

      // 2) Convert doc['duration'] from SECONDS to MINUTES
      final int secs = parseDuration(doc['duration']); // parse as int
      final int minutes = secs ~/ 60; // integer division
      durationSumInMinutes += minutes;

      // 3) Store session time for streak logic
      sessions.add(dt);
    }

    // Sort sessions by ascending time for streak calculations
    sessions.sort();

    // Calculate average in minutes
    double average = (total > 0) ? (durationSumInMinutes / total) : 0.0;

    // Allowed rest days (from your existing code)
    int allowedMiss = 7 - expectedWorkoutDays;

    // Streaks
    int curStreak = _calculateCurrentStreak(sessions, allowedMiss);
    int maxStreak = _calculateLongestStreak(sessions, allowedMiss);

    setState(() {
      totalWorkouts = total;
      workoutsThisMonth = thisMonth;
      totalDuration = durationSumInMinutes; // total duration in minutes
      avgDuration = average; // average in minutes (double)
      currentStreak = curStreak;
      longestStreak = maxStreak;
    });
  }

  /// Current streak: start from the last session, go backward until gap > allowedMiss
  int _calculateCurrentStreak(List<DateTime> sessions, int allowedMiss) {
    if (sessions.isEmpty) return 0;

    int streak = 1;
    // Move backward from the last session
    for (int i = sessions.length - 1; i > 0; i--) {
      final gap = sessions[i].difference(sessions[i - 1]).inDays;
      if ((gap - 1) <= allowedMiss) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Longest streak: forward pass, reset when gap > allowedMiss
  int _calculateLongestStreak(List<DateTime> sessions, int allowedMiss) {
    if (sessions.isEmpty) return 0;
    if (sessions.length == 1) return 1;

    int maxStreak = 1;
    int streak = 1;

    for (int i = 1; i < sessions.length; i++) {
      final gap = sessions[i].difference(sessions[i - 1]).inDays;
      if ((gap - 1) <= allowedMiss) {
        streak++;
      } else {
        streak = 1;
      }
      if (streak > maxStreak) {
        maxStreak = streak;
      }
    }
    return maxStreak;
  }

  // --------------------------
  // 2) Weekly Bar Chart
  // --------------------------
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
      final DateTime dt = ts.toDate();
      final monday = _mondayOfWeek(dt);

      weeklyCounts[monday] = (weeklyCounts[monday] ?? 0) + 1;
    }

    final allMondays = weeklyCounts.keys.toList()..sort();
    List<BarChartGroupData> groups = [];
    for (int i = 0; i < allMondays.length; i++) {
      final monday = allMondays[i];
      final count = weeklyCounts[monday] ?? 0;
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Color(0xFF007AFF),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    // Calculate maxY based on the highest bar
    double tempMaxY = 0;
    for (var g in groups) {
      if (g.barRods.isNotEmpty) {
        tempMaxY = math.max(tempMaxY, g.barRods.first.toY);
      }
    }
    // If above 10, round up to next multiple of 5
    if (tempMaxY > 10) {
      final remainder = tempMaxY % 5;
      if (remainder != 0) {
        tempMaxY = tempMaxY + (5 - remainder);
      }
    }

    setState(() {
      sortedWeekDates = allMondays;
      weeklyBarGroups = groups;
      // If still below 10, we want at least 10 on the Y axis
      maxYForChart = tempMaxY < 10 ? 10 : tempMaxY;
    });
  }

  /// Monday of the given date's week
  DateTime _mondayOfWeek(DateTime date) {
    int delta = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: delta));
  }

  // --------------------------
  // 3) UI Helpers
  // --------------------------
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return "Unknown date";
    final dt = ts.toDate();
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _showStreakSettingsDialog() async {
    int selectedDays = expectedWorkoutDays;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Configure Workout Days/Week"),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return DropdownButton<int>(
                value: selectedDays,
                items: List.generate(7, (index) {
                  final day = index + 1;
                  return DropdownMenuItem<int>(
                    value: day,
                    child: Text("$day days"),
                  );
                }),
                onChanged: (newValue) {
                  setStateDialog(() {
                    selectedDays = newValue!;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text("Save"),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  expectedWorkoutDays = selectedDays;
                });
                _fetchWorkoutStats();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    VoidCallback? onSettingsTap,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with optional settings icon
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ),
              if (onSettingsTap != null)
                GestureDetector(
                  onTap: onSettingsTap,
                  child: Icon(Icons.settings, size: 16, color: Colors.white),
                ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedStatCard({
    required String title,
    required String value,
    VoidCallback? onSettingsTap,
  }) {
    return Expanded(
      child: _buildStatCard(title: title, value: value, onSettingsTap: onSettingsTap),
    );
  }

  // --------------------------
  // 4) Build UI
  // --------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000015),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF000015),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Workout Log', style: TextStyle(color: Colors.white)),
            IconButton(
              icon: Icon(Icons.history, color: Color(0xFF007AFF)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WorkoutHistoryPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStartWorkoutButton(context),
              SizedBox(height: 20),
              _buildWorkoutStats(),
              SizedBox(height: 20),
              _buildFavoriteWorkoutsTile(),
              SizedBox(height: 20),
              _buildWeeklyChart(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartWorkoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF007AFF),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WorkoutSessionPage()),
          );
        },
        child: Text('Start a Workout', style: TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }

  Widget _buildWorkoutStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Workout Stats", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 10),
        // Row 1
        Row(
          children: [
            _buildExpandedStatCard(title: "Total Workouts", value: "$totalWorkouts"),
            SizedBox(width: 8),
            _buildExpandedStatCard(title: "Workouts This Month", value: "$workoutsThisMonth"),
          ],
        ),
        SizedBox(height: 8),
        // Row 2
        Row(
          children: [
            _buildExpandedStatCard(title: "Avg. Duration", value: "${avgDuration.toStringAsFixed(0)} min"),
            SizedBox(width: 8),
            _buildExpandedStatCard(title: "Total Time", value: "$totalDuration min"),
          ],
        ),
        SizedBox(height: 8),
        // Row 3
        Row(
          children: [
            _buildExpandedStatCard(
              title: "Streak",
              value: "$currentStreak day${currentStreak == 1 ? "" : "s"}",
              onSettingsTap: _showStreakSettingsDialog,
            ),
            SizedBox(width: 8),
            _buildExpandedStatCard(
              title: "Longest Streak",
              value: "$longestStreak day${longestStreak == 1 ? "" : "s"}",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFavoriteWorkoutsTile() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FavoriteWorkoutsPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Favorite Workouts",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Workouts per week", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 10),
        Container(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxYForChart,
              minY: 0,
              barGroups: weeklyBarGroups,
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                  left: BorderSide(color: Colors.white24, width: 1),
                  right: BorderSide(color: Colors.transparent),
                  top: BorderSide(color: Colors.transparent),
                ),
              ),
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value % 1 != 0) return Container();
                      final int intVal = value.toInt();
                      if (intVal >= 0 && intVal <= 10) {
                        return Text('$intVal', style: TextStyle(color: Colors.white));
                      } else if (intVal > 10 && intVal % 5 == 0) {
                        return Text('$intVal', style: TextStyle(color: Colors.white));
                      }
                      return Container();
                    },
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
                      final label = DateFormat("M/d").format(date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(label, style: TextStyle(fontSize: 10, color: Colors.white)),
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
