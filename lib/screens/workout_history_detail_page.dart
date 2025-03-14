import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gymworkoutlogger/providers/unit_provider.dart';
import 'package:gymworkoutlogger/utils/unit_converter.dart';

import 'workout_session_page.dart';

class WorkoutHistoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> workout;
  final String workoutId;

  const WorkoutHistoryDetailPage({
    Key? key,
    required this.workout,
    required this.workoutId,
  }) : super(key: key);

  @override
  _WorkoutHistoryDetailPageState createState() =>
      _WorkoutHistoryDetailPageState();
}

class _WorkoutHistoryDetailPageState extends State<WorkoutHistoryDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  bool isFavorited = false;
  String? workoutDurationString;

  @override
  void initState() {
    super.initState();
    _commentController.text = widget.workout['comments'] ?? '';
    isFavorited = widget.workout['favorited'] == true;

    // Format the top-level workout duration (stored in seconds).
    final durationValue = widget.workout['duration'];
    if (durationValue != null) {
      final durationInSeconds = durationValue is int
          ? durationValue
          : int.tryParse(durationValue.toString()) ?? 0;
      workoutDurationString = _formatDuration(durationInSeconds);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Converts a number of seconds into an h/m/s string (e.g. "1h 10m 30s").
  /// If the total is zero, returns "0s".
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    final buffer = StringBuffer();
    if (hours > 0) buffer.write('${hours}h ');
    if (minutes > 0) buffer.write('${minutes}m ');
    if (secs > 0) buffer.write('${secs}s');
    return buffer.isEmpty ? '0s' : buffer.toString().trim();
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      isFavorited = !isFavorited;
    });

    try {
      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .update({'favorited': isFavorited});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorited ? 'Added to favorites!' : 'Removed from favorites!',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isFavorited = !isFavorited;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update favorite: $e')),
      );
    }
  }

  int _calculateTotalVolume() {
    int totalVolume = 0;
    final exercises = widget.workout['exercises'] ?? [];
    for (var exercise in exercises) {
      if (exercise['sets'] is List) {
        for (var set in exercise['sets']) {
          final weight = (set['weight'] ?? 0) as num;
          final reps = (set['reps'] ?? 0) as num;
          totalVolume += (weight * reps).toInt();
        }
      }
    }
    return totalVolume;
  }

  Future<void> _saveComment() async {
    try {
      await FirebaseFirestore.instance
          .collection('workouts')
          .doc(widget.workoutId)
          .update({'comments': _commentController.text});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save comment: $e')),
      );
    }
  }

  /// Displays cardio data when `sets` is a single Map (e.g. `"sets": {"duration":..., "distance":..., "reps":...}`).
  Widget _buildCardioFields(Map<String, dynamic> exercise) {
    final setsField = exercise['sets'];
    final unitProvider = Provider.of<UnitProvider>(context, listen: false);

    if (setsField is Map<String, dynamic>) {
      final duration = setsField['duration'];
      final distance = setsField['distance'];
      final reps = setsField['reps'];

      if (duration == null && distance == null && reps == null) {
        return Text(
          "No cardio data logged",
          style: TextStyle(color: Theme.of(context).hintColor),
        );
      }

      final List<Widget> cardioWidgets = [];

      if (duration != null) {
        final durationInSec = duration is int
            ? duration
            : int.tryParse(duration.toString()) ?? 0;
        cardioWidgets.add(
          Text(
            "Duration: ${_formatDuration(durationInSec)}",
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        );
      }

      if (distance != null) {
        double distanceValue = double.tryParse(distance.toString()) ?? 0.0;
        if (unitProvider.useMetric) {
          distanceValue = UnitConverter.milesToKm(distanceValue);
          cardioWidgets.add(Text(
            "Distance: ${distanceValue.toStringAsFixed(2)} km",
            style: TextStyle(color: Theme.of(context).hintColor),
          ));
        } else {
          cardioWidgets.add(Text(
            "Distance: ${distanceValue.toStringAsFixed(2)} mi",
            style: TextStyle(color: Theme.of(context).hintColor),
          ));
        }
      }

      if (reps != null) {
        cardioWidgets.add(
          Text(
            "Reps: $reps",
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        );
      }

      return Row(
        children: cardioWidgets
            .map((w) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: w,
        ))
            .toList(),
      );
    }

    return Text(
      "No cardio data logged",
      style: TextStyle(color: Theme.of(context).hintColor),
    );
  }

  /// Displays strength/cardio data when `sets` is a List of maps.
  List<Widget> _buildStrengthSets(List setsList) {
    final widgets = <Widget>[];
    final unitProvider = Provider.of<UnitProvider>(context);

    for (int i = 0; i < setsList.length; i++) {
      final setData = setsList[i] as Map<String, dynamic>;

      // If it's cardio-only data (duration, distance, or reps), but no weight
      if ((setData.containsKey('duration') ||
          setData.containsKey('distance') ||
          setData.containsKey('reps')) &&
          !setData.containsKey('weight')) {
        final duration = setData['duration'];
        final distance = setData['distance'];
        final reps = setData['reps'];

        final List<Widget> cardioWidgets = [];

        if (duration != null) {
          final durationInSec = duration is int
              ? duration
              : int.tryParse(duration.toString()) ?? 0;
          cardioWidgets.add(
            Text(
              "Duration: ${_formatDuration(durationInSec)}",
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }

        if (distance != null) {
          double distanceValue = double.tryParse(distance.toString()) ?? 0.0;
          if (unitProvider.useMetric) {
            distanceValue = UnitConverter.milesToKm(distanceValue);
            cardioWidgets.add(Text(
              "Distance: ${distanceValue.toStringAsFixed(2)} km",
              style: TextStyle(color: Theme.of(context).hintColor),
            ));
          } else {
            cardioWidgets.add(Text(
              "Distance: ${distanceValue.toStringAsFixed(2)} mi",
              style: TextStyle(color: Theme.of(context).hintColor),
            ));
          }
        }

        if (reps != null) {
          cardioWidgets.add(
            Text(
              "Reps: $reps",
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }

        widgets.add(
          Row(
            children: cardioWidgets
                .map((w) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: w,
            ))
                .toList(),
          ),
        );
      } else {
        // Otherwise, assume strength sets (weight & reps)
        final weight = setData['weight'];
        final reps = setData['reps'];
        if (weight == null && reps == null) continue;

        double weightValue = 0.0;
        if (weight is int) {
          weightValue = weight.toDouble();
        } else if (weight is double) {
          weightValue = weight;
        } else {
          weightValue = double.tryParse(weight.toString()) ?? 0.0;
        }

        // Convert lbs to kg if user wants metric
        if (unitProvider.useMetric) {
          weightValue = UnitConverter.lbsToKg(weightValue);
        }
        String unitLabel = unitProvider.useMetric ? "kg" : "lbs";

        widgets.add(
          Text(
            "Set ${i + 1}: Weight: ${weightValue.toStringAsFixed(2)} $unitLabel | Reps: $reps",
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        Text(
          "No sets data for this exercise",
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    DateTime workoutDate = DateTime.now();
    if (widget.workout['timestamp'] is Timestamp) {
      workoutDate = (widget.workout['timestamp'] as Timestamp).toDate();
    }

    final exercises = widget.workout['exercises'] ?? [];
    final totalVolume = _calculateTotalVolume();
    final workoutDescription = widget.workout['description'] ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.workout['name'] ?? 'Workout Details',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFavorited ? Icons.star : Icons.star_border,
              color: isFavorited ? Colors.amber : Colors.grey,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            "Date: ${DateFormat.yMMMd().format(workoutDate)}",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (workoutDurationString != null)
            Text(
              "Duration: $workoutDurationString",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 8),
          if (workoutDescription.isNotEmpty) ...[
            Text(
              "Description:",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              workoutDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Only show total volume if it's non-zero.
          if (totalVolume != 0)
            Consumer<UnitProvider>(
              builder: (context, unitProvider, child) {
                double displayVolume = totalVolume.toDouble();
                if (unitProvider.useMetric) {
                  displayVolume = UnitConverter.lbsToKg(displayVolume);
                }
                return Text(
                  "Total Volume Lifted: ${displayVolume.toStringAsFixed(2)} ${unitProvider.useMetric ? 'kg' : 'lbs'}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Text(
            "Exercises:",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...exercises.map<Widget>((exercise) {
            final exerciseName = exercise['name'] ?? 'Unnamed Exercise';
            final setsField = exercise['sets'];

            return Card(
              color: Theme.of(context).cardColor,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (setsField is Map<String, dynamic>)
                      _buildCardioFields(exercise),
                    if (setsField is List) ..._buildStrengthSets(setsField),
                    if (setsField == null)
                      Text(
                        "No data logged for this exercise",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          if (widget.workout['favorited'] == true) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutSessionPage(
                      preloadedWorkout: widget.workout,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: Text(
                'Start this workout',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            "Comments:",
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'Enter your comment',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            maxLines: null,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _saveComment,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: Text(
              'Save Comment',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
