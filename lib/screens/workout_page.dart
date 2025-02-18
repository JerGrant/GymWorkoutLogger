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

  // Basic stats
  int totalWorkouts = 0;
  int workoutsThisMonth = 0;
  int totalDuration = 0;        // in minutes
  double avgDuration = 0;       // in minutes
  int currentStreak = 0;        // "Streak" from today backward
  int longestStreak = 0;        // maximum streak across entire history

  // Configurable setting: expected workout days per week.
  // This determines how many rest days are allowed without breaking the streak.
  int expectedWorkoutDays = 5;

  // Bar chart data
  List<BarChartGroupData> weeklyBarGroups = [];
  List<DateTime> sortedWeekDates = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkoutStats();
    _fetchWeeklyWorkouts();
  }

  // ----------------------------------------------------
  // 1) Basic Stats Calculation (with configurable streak)
  // ----------------------------------------------------
  Future<void> _fetchWorkoutStats() async {
    if (user == null) return;

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Fetch all workouts for this user
    QuerySnapshot workoutSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: user!.uid)
        .get();

    int total = workoutSnapshot.docs.length;
    int thisMonth = 0;
    int durationSum = 0;

    // Gather all workout days (date-only) for streak calculations
    Set<DateTime> workoutDays = {};

    DateTime? earliestDate; // track earliest workout date for "Longest Streak"

    for (var doc in workoutSnapshot.docs) {
      Timestamp ts = doc['timestamp'];
      DateTime workoutDate = ts.toDate();

      // Count workouts this month
      if (workoutDate.isAfter(startOfMonth)) {
        thisMonth++;
      }

      // Sum up workout duration (assuming 'duration' is stored in minutes)
      if (doc.data().toString().contains('duration')) {
        int duration = doc['duration'] ?? 0;
        durationSum += duration;
      }

      // Store date only (year, month, day)
      DateTime dayOnly = DateTime(workoutDate.year, workoutDate.month, workoutDate.day);
      workoutDays.add(dayOnly);

      // Track earliest date
      if (earliestDate == null || dayOnly.isBefore(earliestDate)) {
        earliestDate = dayOnly;
      }
    }

    // Compute average duration
    double average = (total > 0) ? (durationSum / total) : 0;

    // Compute the current streak (backwards from today)
    int allowedMiss = 7 - expectedWorkoutDays;
    int curStreak = _calculateCurrentStreak(workoutDays, now, allowedMiss);

    // Compute the longest streak (iterate from earliest to now)
    int maxStreak = 0;
    if (earliestDate != null) {
      maxStreak = _calculateLongestStreak(workoutDays, earliestDate, now, allowedMiss);
    }

    setState(() {
      totalWorkouts = total;
      workoutsThisMonth = thisMonth;
      totalDuration = durationSum;
      avgDuration = average;
      currentStreak = curStreak;
      longestStreak = maxStreak;
    });
  }

  /// Calculates the "current" streak by going backward from [startDay] until we exceed allowed rest days.
  int _calculateCurrentStreak(Set<DateTime> workoutDays, DateTime startDay, int allowedMiss) {
    int streak = 0;
    int consecutiveMiss = 0;
    DateTime checkDate = DateTime(startDay.year, startDay.month, startDay.day);

    while (true) {
      if (workoutDays.contains(checkDate)) {
        streak++;
        consecutiveMiss = 0;
      } else {
        consecutiveMiss++;
        if (consecutiveMiss > allowedMiss) break;
        streak++;
      }
      checkDate = checkDate.subtract(Duration(days: 1));
    }
    return streak;
  }

  /// Calculates the "longest" streak by iterating day by day from [startDay] to [endDay],
  /// allowing up to [allowedMiss] consecutive rest days before the streak resets.
  int _calculateLongestStreak(Set<DateTime> workoutDays, DateTime startDay, DateTime endDay, int allowedMiss) {
    int maxStreak = 0;
    int streak = 0;
    int consecutiveMiss = 0;

    // We'll go from startDay to endDay inclusive
    DateTime date = startDay;
    while (!date.isAfter(endDay)) {
      if (workoutDays.contains(date)) {
        streak++;
        consecutiveMiss = 0;
      } else {
        consecutiveMiss++;
        if (consecutiveMiss > allowedMiss) {
          // Reset streak
          streak = 0;
          consecutiveMiss = 0;
        } else {
          // Allowed rest day(s) still count toward the streak
          streak++;
        }
      }
      maxStreak = streak > maxStreak ? streak : maxStreak;
      date = date.add(Duration(days: 1));
    }
    return maxStreak;
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

  /// Opens a dialog to configure the expected workout days per week.
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
                  int day = index + 1;
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
                _fetchWorkoutStats(); // Recalculate streak + longest streak
              },
            ),
          ],
        );
      },
    );
  }

  /// Builds a stat card that optionally shows a settings icon (for the streak).
  Widget _buildStatCard({
    required String title,
    required String value,
    VoidCallback? onSettingsTap,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row + optional settings icon
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (onSettingsTap != null)
                GestureDetector(
                  onTap: onSettingsTap,
                  child: Icon(Icons.settings, size: 16),
                ),
            ],
          ),
          SizedBox(height: 4),
          // The stat value
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // For convenience, an Expanded wrapper around _buildStatCard
  Widget _buildExpandedStatCard({
    required String title,
    required String value,
    VoidCallback? onSettingsTap,
  }) {
    return Expanded(
      child: _buildStatCard(
        title: title,
        value: value,
        onSettingsTap: onSettingsTap,
      ),
    );
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
      body: SingleChildScrollView(
        child: Padding(
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

  /// Displays all workout stats in a 2x2x2 layout to fit six stats:
  /// 1) Total Workouts 2) Workouts This Month
  /// 3) Avg. Duration   4) Total Time
  /// 5) Streak          6) Longest Streak
  Widget _buildWorkoutStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workout Stats',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),

        // Row 1: Total Workouts / Workouts This Month
        Row(
          children: [
            _buildExpandedStatCard(
              title: 'Total Workouts',
              value: '$totalWorkouts',
            ),
            SizedBox(width: 8),
            _buildExpandedStatCard(
              title: 'Workouts This Month',
              value: '$workoutsThisMonth',
            ),
          ],
        ),
        SizedBox(height: 8),

        // Row 2: Avg. Duration / Total Time
        Row(
          children: [
            _buildExpandedStatCard(
              title: 'Avg. Duration',
              value: '${avgDuration.toStringAsFixed(0)} min',
            ),
            SizedBox(width: 8),
            _buildExpandedStatCard(
              title: 'Total Time',
              value: '$totalDuration min',
            ),
          ],
        ),
        SizedBox(height: 8),

        // Row 3: Streak (with gear) / Longest Streak
        Row(
          children: [
            _buildExpandedStatCard(
              title: 'Streak',
              value: '$currentStreak day${currentStreak == 1 ? "" : "s"}',
              onSettingsTap: _showStreakSettingsDialog,
            ),
            SizedBox(width: 8),
            _buildExpandedStatCard(
              title: 'Longest Streak',
              value: '$longestStreak day${longestStreak == 1 ? "" : "s"}',
            ),
          ],
        ),
      ],
    );
  }

  /// Displays the weekly bar chart with labels under the x-axis.
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
