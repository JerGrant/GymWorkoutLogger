import 'dart:async';
import 'dart:math'; // For max(...)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymworkoutlogger/providers/unit_provider.dart';
import 'package:gymworkoutlogger/screens/exercise_selection_modal.dart';
import 'package:gymworkoutlogger/utils/unit_converter.dart';

class WorkoutSessionPage extends StatefulWidget {
  final Map<String, dynamic>? preloadedWorkout;

  const WorkoutSessionPage({Key? key, this.preloadedWorkout}) : super(key: key);

  @override
  _WorkoutSessionPageState createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;

  // Main workout duration timer
  Timer? _timer;
  int _duration = 0;

  // Top Timer (for the AppBar timer icon)
  Timer? _topTimer;
  bool _topTimerActive = false;
  int _topTimerTotal = 120; // default total = 2 minutes (120 sec)
  final ValueNotifier<int> _topTimerNotifier = ValueNotifier<int>(120);

  // Basic workout info
  String _workoutName = "Untitled Workout";
  String _workoutDescription = "";
  DocumentReference? _workoutRef;
  List<Map<String, dynamic>> _selectedExercises = [];
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _workoutNameController = TextEditingController();
  final TextEditingController _workoutDescriptionController =
  TextEditingController();

  @override
  void initState() {
    super.initState();

    // Preload data if provided
    if (widget.preloadedWorkout != null) {
      _workoutName = widget.preloadedWorkout!['name'] ?? "Untitled Workout";
      _workoutDescription =
          widget.preloadedWorkout!['description'] ?? "";
      _selectedExercises = widget.preloadedWorkout!['exercises'] != null
          ? List<Map<String, dynamic>>.from(
          widget.preloadedWorkout!['exercises'])
          : [];

      // Initialize controllers & focusNodes for each set
      for (var exercise in _selectedExercises) {
        exercise['controllers'] ??= [];
        exercise['focusNodes'] ??= [];
        for (var i = 0; i < (exercise['sets']?.length ?? 0); i++) {
          Map<String, TextEditingController> ctrl = {};
          Map<String, FocusNode> nodes = {};

          // Initialize rest-timer fields
          exercise['sets'][i]['isSetComplete'] ??= false;
          exercise['sets'][i]['restRemaining'] ??= 120;
          exercise['sets'][i]['restTotal'] ??= 120;
          exercise['sets'][i]['restTimer'] = null;
          exercise['sets'][i]['isRestActive'] ??= false;

          // Reps field
          if (exercise['sets'][i].containsKey('reps')) {
            final repsVal = exercise['sets'][i]['reps'];
            ctrl['reps'] = TextEditingController(
              text: (repsVal == null || repsVal == 0) ? "" : repsVal.toString(),
            );
            nodes['reps'] = FocusNode();
            nodes['reps']!.addListener(() {
              if (nodes['reps']!.hasFocus) {
                ctrl['reps']!.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: ctrl['reps']!.text.length,
                );
              } else {
                _verifyAndUpdateReps(
                  _selectedExercises.indexOf(exercise),
                  i,
                  ctrl['reps']!.text,
                );
              }
            });
          }

          // Weight field
          if (exercise['sets'][i].containsKey('weight')) {
            final weightVal = exercise['sets'][i]['weight'];
            ctrl['weight'] = TextEditingController(
              text: (weightVal == null || weightVal == 0.0)
                  ? ""
                  : weightVal.toString(),
            );
            nodes['weight'] = FocusNode();
            nodes['weight']!.addListener(() {
              if (nodes['weight']!.hasFocus) {
                ctrl['weight']!.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: ctrl['weight']!.text.length,
                );
              } else {
                _verifyAndUpdateWeight(
                  _selectedExercises.indexOf(exercise),
                  i,
                  ctrl['weight']!.text,
                );
              }
            });
          }

          // Distance field – always stored in miles
          if (exercise['sets'][i].containsKey('distance')) {
            final distVal = exercise['sets'][i]['distance'];
            ctrl['distance'] = TextEditingController(
              text: (distVal == null || distVal == 0.0)
                  ? ""
                  : distVal.toString(),
            );
            nodes['distance'] = FocusNode();
            nodes['distance']!.addListener(() {
              if (nodes['distance']!.hasFocus) {
                ctrl['distance']!.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: ctrl['distance']!.text.length,
                );
              } else {
                _verifyAndUpdateDistance(
                  _selectedExercises.indexOf(exercise),
                  i,
                  ctrl['distance']!.text,
                );
              }
            });
          }
          // Duration field if needed, same pattern

          exercise['controllers'].add(ctrl);
          exercise['focusNodes'].add(nodes);
        }
      }
    }

    // Initialize text controllers
    _workoutNameController.text = _workoutName;
    _workoutDescriptionController.text = _workoutDescription;

    _workoutNameController.addListener(() {
      setState(() {
        _workoutName = _workoutNameController.text;
      });
    });
    _workoutDescriptionController.addListener(() {
      setState(() {
        _workoutDescription = _workoutDescriptionController.text;
      });
    });

    _startWorkout();
  }

  // Create workout document and start main timer.
  Future<void> _startWorkout() async {
    if (user == null) return;

    // Remove ephemeral keys before storing
    List<Map<String, dynamic>> cleanedExercises = _selectedExercises.map((exercise) {
      final copy = Map<String, dynamic>.from(exercise);
      copy.remove('controllers');
      copy.remove('focusNodes');
      if (copy['sets'] is List) {
        for (var setMap in (copy['sets'] as List)) {
          setMap.remove('restTimer');
        }
      }
      return copy;
    }).toList();

    _workoutRef = await _firestore.collection('workouts').add({
      'userId': user!.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'duration': 0,
      'name': _workoutName,
      'description': _workoutDescription,
      'exercises': cleanedExercises,
    });
    _startMainTimer();
    debugPrint("Created doc: ${_workoutRef!.id}");
  }

  void _startMainTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  // --- TOP TIMER LOGIC ---
  String _formatMMSS(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  void _startTopTimer() {
    _topTimer?.cancel();
    _topTimerNotifier.value = _topTimerTotal;
    _topTimerActive = true;
    _topTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_topTimerNotifier.value > 0) {
        _topTimerNotifier.value--;
      } else {
        timer.cancel();
        _topTimerActive = false;
      }
    });
  }

  void _stopTopTimer() {
    _topTimer?.cancel();
    _topTimerActive = false;
  }

  void _showTopTimerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Timer"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: _topTimerNotifier,
                builder: (context, value, child) {
                  return Text(
                    _formatMMSS(value),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<int>(
                valueListenable: _topTimerNotifier,
                builder: (context, value, child) {
                  double fractionLeft =
                  _topTimerTotal == 0 ? 0 : value / _topTimerTotal;
                  return LinearProgressIndicator(
                    value: fractionLeft,
                    minHeight: 8,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _topTimerTotal += 30;
                        _topTimerNotifier.value += 30;
                      });
                    },
                    child: const Text("+30s"),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      setState(() {
                        _topTimerTotal = max<int>(0, _topTimerTotal - 30);
                        _topTimerNotifier.value =
                            max<int>(0, _topTimerNotifier.value - 30);
                      });
                    },
                    child: const Text("-30s"),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (!_topTimerActive)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _startTopTimer();
                  });
                },
                child: const Text("Start"),
              ),
            if (_topTimerActive)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _stopTopTimer();
                  });
                },
                child: const Text("Stop"),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // --- FINISH/CANCEL WORKOUT ---
  Future<void> _finishWorkout() async {
    _timer?.cancel();
    debugPrint("Finishing workout with duration: $_duration");

    // Process each exercise's sets
    for (int i = 0; i < _selectedExercises.length; i++) {
      for (int j = 0; j < (_selectedExercises[i]['sets']?.length ?? 0); j++) {
        var repsCtrl = _selectedExercises[i]['controllers'][j]['reps'];
        var weightCtrl = _selectedExercises[i]['controllers'][j]['weight'];
        var distCtrl = _selectedExercises[i]['controllers'][j]['distance'];

        // Reps update
        if (repsCtrl != null) {
          int reps = int.tryParse(repsCtrl.text) ?? 0;
          _updateReps(i, j, reps);
        }

        // Weight update
        if (weightCtrl != null) {
          double w = double.tryParse(weightCtrl.text) ?? 0.0;
          final unitProvider = Provider.of<UnitProvider>(context, listen: false);
          if (unitProvider.useMetric) {
            w = UnitConverter.kgToLbs(w);
          }
          _updateWeight(i, j, w);
        }

        // Distance update
        if (distCtrl != null) {
          double d = double.tryParse(distCtrl.text) ?? 0.0;
          final unitProvider = Provider.of<UnitProvider>(context, listen: false);
          // If user is in metric, the input is in km; convert to miles
          if (unitProvider.useMetric) {
            d = UnitConverter.kmToMiles(d);
          }
          _updateDistance(i, j, d);
        }
      }
    }

    // Clean out ephemeral keys
    List<Map<String, dynamic>> cleanedExercises = _selectedExercises.map((exercise) {
      var cleaned = Map<String, dynamic>.from(exercise);
      cleaned.remove("controllers");
      cleaned.remove("focusNodes");
      if (cleaned['sets'] is List) {
        for (var setMap in (cleaned['sets'] as List)) {
          setMap.remove('restTimer');
        }
      }
      return cleaned;
    }).toList();

    try {
      if (_workoutRef != null) {
        await _workoutRef!.update({
          'duration': _duration,
          'name': _workoutName,
          'description': _workoutDescription,
          'exercises': cleanedExercises,
        });
        debugPrint("Workout document updated successfully.");
      } else {
        debugPrint("Workout document reference is null.");
      }
    } catch (e) {
      debugPrint("Error updating workout document: $e");
    }

    Navigator.pop(context);
  }

  Future<void> _cancelWorkout() async {
    _timer?.cancel();
    _topTimer?.cancel();
    await _workoutRef?.delete();
    Navigator.pop(context);
  }

  // --- EXERCISE SELECTION ---
  Map<String, dynamic> convertExerciseFields(Map<String, dynamic> exercise) {
    List<String> fields = ['name', 'category', 'bodyPart', 'subcategory'];
    Map<String, dynamic> newExercise = Map.from(exercise);
    for (var field in fields) {
      if (newExercise.containsKey(field)) {
        if (newExercise[field] is List) {
          newExercise[field] =
              (newExercise[field] as List).map((e) => e.toString()).join(', ');
        } else if (newExercise[field] == null) {
          newExercise[field] = '';
        }
      } else {
        newExercise[field] = '';
      }
    }
    if (!(newExercise['sets'] is List)) {
      newExercise['sets'] = [];
    }
    return newExercise;
  }

  void _openExerciseSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ExerciseSelectionModal(
          onExercisesSelected: (selected) {
            setState(() {
              for (var exercise in selected) {
                Map<String, dynamic> fixedExercise =
                convertExerciseFields(exercise);
                fixedExercise['id'] = exercise['id'];
                fixedExercise['controllers'] =
                <Map<String, TextEditingController>>[];
                fixedExercise['focusNodes'] = <Map<String, FocusNode>>[];
                _selectedExercises.add(fixedExercise);
              }
            });
          },
        ),
      ),
    );
  }

  void _removeExercise(int index) {
    setState(() {
      for (var map in _selectedExercises[index]['controllers']) {
        map.values.forEach((c) => c.dispose());
      }
      for (var map in _selectedExercises[index]['focusNodes']) {
        map.values.forEach((node) => node.dispose());
      }
      _selectedExercises.removeAt(index);
    });
  }

  /// Default set structure for new sets.
  Map<String, dynamic> _getDefaultSet(String category) {
    final lower = category.toLowerCase();
    if (lower.contains("cardio")) {
      return {
        'distance': null, // Stored in miles
        'duration': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    } else if (lower.contains("lap")) {
      return {
        'reps': null,
        'duration': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    } else if (lower.contains("isometric")) {
      return {
        'reps': null,
        'weight': null,
        'duration': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    } else if (lower.contains("stretching") ||
        lower.contains("mobility") ||
        lower == "duration") {
      return {
        'duration': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    } else if (lower.contains("assisted body")) {
      return {
        'reps': null,
        'weight': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    } else if (lower.contains("non-weight")) {
      return {
        'reps': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    } else {
      return {
        'reps': null,
        'weight': null,
        'isSetComplete': false,
        'restRemaining': 120,
        'restTotal': 120,
        'restTimer': null,
        'isRestActive': false,
      };
    }
  }

  Future<List<dynamic>> _fetchLastPerformedSets(String exerciseId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    final workoutsSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in workoutsSnapshot.docs) {
      List exercises = doc['exercises'] ?? [];
      for (var ex in exercises) {
        if (ex['id'] == exerciseId) {
          List sets = ex['sets'] ?? [];
          if (sets.isNotEmpty) {
            return sets;
          }
        }
      }
    }
    return [];
  }

  /// Prefill values from the last performed set.
  Future<Map<String, String>> _getPrefillFromLastWorkout(String exerciseId) async {
    final setsFromLast = await _fetchLastPerformedSets(exerciseId);
    if (setsFromLast.isEmpty) {
      return {'reps': '', 'weight': '', 'distance': ''};
    }
    final lastSet = setsFromLast.last;
    final unitProvider = Provider.of<UnitProvider>(context, listen: false);

    // Reps
    int reps = 0;
    if (lastSet['reps'] is int) {
      reps = lastSet['reps'];
    } else {
      reps = int.tryParse(lastSet['reps']?.toString() ?? "") ?? 0;
    }

    // Weight
    double weightVal = 0.0;
    if (lastSet['weight'] is int) {
      weightVal = (lastSet['weight'] as int).toDouble();
    } else if (lastSet['weight'] is double) {
      weightVal = lastSet['weight'];
    }
    if (unitProvider.useMetric) {
      weightVal = UnitConverter.lbsToKg(weightVal);
    }

    // Distance
    double distVal = 0.0;
    if (lastSet['distance'] is int) {
      distVal = (lastSet['distance'] as int).toDouble();
    } else if (lastSet['distance'] is double) {
      distVal = lastSet['distance'];
    }
    if (unitProvider.useMetric) {
      // Convert stored miles to km for display
      distVal = UnitConverter.milesToKm(distVal);
    }

    return {
      'reps': reps == 0 ? '' : reps.toString(),
      'weight': weightVal == 0.0 ? '' : weightVal.toStringAsFixed(1),
      'distance': distVal == 0.0 ? '' : distVal.toStringAsFixed(2),
    };
  }

  Future<void> _addSet(int exerciseIndex) async {
    final exercise = _selectedExercises[exerciseIndex];
    final category = exercise['category']?.toString() ?? "";
    final newSet = _getDefaultSet(category);
    final newSetIndex = exercise['sets'].length;

    int lastSetIndex = (exercise['sets']?.length ?? 0) - 1;
    String initialRepsText = "";
    String initialWeightText = "";
    String initialDistanceText = "";

    // If no sets yet, try to prefill from last workout
    if (lastSetIndex < 0) {
      final prefill = await _getPrefillFromLastWorkout(exercise['id']);
      initialRepsText = prefill['reps'] ?? "";
      initialWeightText = prefill['weight'] ?? "";
      initialDistanceText = prefill['distance'] ?? "";
    } else {
      // Otherwise copy from last set in this workout
      initialRepsText =
          exercise['controllers'][lastSetIndex]['reps']?.text ?? "";
      initialWeightText =
          exercise['controllers'][lastSetIndex]['weight']?.text ?? "";
      initialDistanceText =
          exercise['controllers'][lastSetIndex]['distance']?.text ?? "";
    }

    Map<String, TextEditingController> newControllers = {};
    Map<String, FocusNode> newFocusNodes = {};

    if (newSet.containsKey('reps')) {
      newControllers['reps'] = TextEditingController(text: initialRepsText);
      newFocusNodes['reps'] = FocusNode();
      newFocusNodes['reps']!.addListener(() {
        if (newFocusNodes['reps']!.hasFocus) {
          newControllers['reps']!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: newControllers['reps']!.text.length,
          );
        } else {
          _verifyAndUpdateReps(
            exerciseIndex,
            newSetIndex,
            newControllers['reps']!.text,
          );
        }
      });
    }

    if (newSet.containsKey('weight')) {
      newControllers['weight'] = TextEditingController(text: initialWeightText);
      newFocusNodes['weight'] = FocusNode();
      newFocusNodes['weight']!.addListener(() {
        if (newFocusNodes['weight']!.hasFocus) {
          newControllers['weight']!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: newControllers['weight']!.text.length,
          );
        } else {
          _verifyAndUpdateWeight(
            exerciseIndex,
            newSetIndex,
            newControllers['weight']!.text,
          );
        }
      });
    }

    if (newSet.containsKey('distance')) {
      newControllers['distance'] =
          TextEditingController(text: initialDistanceText);
      newFocusNodes['distance'] = FocusNode();
      newFocusNodes['distance']!.addListener(() {
        if (newFocusNodes['distance']!.hasFocus) {
          newControllers['distance']!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: newControllers['distance']!.text.length,
          );
        } else {
          _verifyAndUpdateDistance(
            exerciseIndex,
            newSetIndex,
            newControllers['distance']!.text,
          );
        }
      });
    }

    setState(() {
      exercise['sets'].add(newSet);
      exercise['controllers'] ??= <Map<String, TextEditingController>>[];
      exercise['focusNodes'] ??= <Map<String, FocusNode>>[];
      exercise['controllers'].add(newControllers);
      exercise['focusNodes'].add(newFocusNodes);
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    final exercise = _selectedExercises[exerciseIndex];
    exercise['controllers'][setIndex].values.forEach((c) => c.dispose());
    exercise['focusNodes'][setIndex].values.forEach((n) => n.dispose());

    if (exercise['sets'][setIndex]['restTimer'] != null) {
      (exercise['sets'][setIndex]['restTimer'] as Timer).cancel();
    }

    setState(() {
      exercise['sets'].removeAt(setIndex);
      exercise['controllers'].removeAt(setIndex);
      exercise['focusNodes'].removeAt(setIndex);
    });
  }

  // Reps update
  void _updateReps(int exerciseIndex, int setIndex, int reps) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['reps'] = reps;
    });
  }

  // Weight update
  void _updateWeight(int exerciseIndex, int setIndex, double weight) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['weight'] = weight;
    });
  }

  // Distance update
  void _updateDistance(int exerciseIndex, int setIndex, double dist) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['distance'] = dist;
    });
  }

  void _updateDuration(int exerciseIndex, int setIndex, int duration) {
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['duration'] = duration;
    });
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) {
      return "${hours}h ${minutes}m ${remainingSeconds}s";
    }
    return "${minutes}m ${remainingSeconds}s";
  }

  String _formatRestMMSS(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
  }

  void _onSetCheckChanged(int exerciseIndex, int setIndex, bool? val) {
    if (val == null) return;
    setState(() {
      _selectedExercises[exerciseIndex]['sets'][setIndex]['isSetComplete'] = val;
    });
    if (val) {
      _startSetRestTimer(exerciseIndex, setIndex);
    } else {
      _stopSetRestTimer(exerciseIndex, setIndex);
    }
  }

  void _startSetRestTimer(int exerciseIndex, int setIndex) {
    final setData = _selectedExercises[exerciseIndex]['sets'][setIndex];
    if (setData['restTimer'] != null) {
      (setData['restTimer'] as Timer).cancel();
    }
    setData['isRestActive'] = true;
    setData['restTotal'] ??= setData['restRemaining'];
    setData['restTimer'] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if ((setData['restRemaining'] as int) > 0) {
          setData['restRemaining'] = (setData['restRemaining'] as int) - 1;
        } else {
          timer.cancel();
          setData['isRestActive'] = false;
        }
      });
    });
  }

  void _stopSetRestTimer(int exerciseIndex, int setIndex) {
    final setData = _selectedExercises[exerciseIndex]['sets'][setIndex];
    if (setData['restTimer'] != null) {
      (setData['restTimer'] as Timer).cancel();
      setData['restTimer'] = null;
    }
    setData['isRestActive'] = false;
  }

  Future<bool> _showVerificationDialog(String message) async {
    return (await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          "Confirm Value",
          style: (Theme.of(context).textTheme.bodyMedium ??
              const TextStyle()),
        ),
        content: Text(
          message,
          style: (Theme.of(context).textTheme.bodyMedium ??
              const TextStyle())
              .copyWith(color: Theme.of(context).hintColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    )) ??
        false;
  }

  Future<void> _verifyAndUpdateReps(
      int exerciseIndex, int setIndex, String valueStr) async {
    int reps = int.tryParse(valueStr) ?? 0;
    if (reps > 100) {
      bool confirmed =
      await _showVerificationDialog("You entered over 100 reps. Are you sure?");
      if (!confirmed) {
        setState(() {
          _selectedExercises[exerciseIndex]['sets'][setIndex]['reps'] = null;
          _selectedExercises[exerciseIndex]['controllers'][setIndex]['reps']
              ?.text = "";
        });
        return;
      }
    }
    _updateReps(exerciseIndex, setIndex, reps);
  }

  Future<void> _verifyAndUpdateWeight(
      int exerciseIndex, int setIndex, String valueStr) async {
    double weightVal = double.tryParse(valueStr) ?? 0.0;
    final unitProvider = Provider.of<UnitProvider>(context, listen: false);
    if (unitProvider.useMetric) {
      weightVal = UnitConverter.kgToLbs(weightVal);
    }
    if (weightVal > 500) {
      bool confirmed = await _showVerificationDialog(
          "You entered over 500 lbs. Are you sure?");
      if (!confirmed) {
        setState(() {
          _selectedExercises[exerciseIndex]['sets'][setIndex]['weight'] = null;
          _selectedExercises[exerciseIndex]['controllers'][setIndex]['weight']
              ?.text = "";
        });
        return;
      }
    }
    _updateWeight(exerciseIndex, setIndex, weightVal);
  }

  Future<void> _verifyAndUpdateDistance(
      int exerciseIndex, int setIndex, String valueStr) async {
    double distVal = double.tryParse(valueStr) ?? 0.0;
    final unitProvider = Provider.of<UnitProvider>(context, listen: false);
    // If user is in metric, their input is in km; convert to miles
    if (unitProvider.useMetric) {
      distVal = UnitConverter.kmToMiles(distVal);
    }
    if (distVal > 100) {
      bool confirmed = await _showVerificationDialog(
          "You entered over 100 miles. Are you sure?");
      if (!confirmed) {
        setState(() {
          _selectedExercises[exerciseIndex]['sets'][setIndex]['distance'] =
          null;
          _selectedExercises[exerciseIndex]['controllers'][setIndex]['distance']
              ?.text = "";
        });
        return;
      }
    }
    _updateDistance(exerciseIndex, setIndex, distVal);
  }

  // --- EXERCISE HISTORY LOGIC ---
  Future<Map<String, dynamic>> _fetchExerciseHistory(String exerciseId) async {
    List<Map<String, dynamic>> allEntries = [];
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return {'bestEntry': null, 'recent': []};

    final workoutsSnapshot = await _firestore
        .collection('workouts')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .get();

    double maxVolume = 0.0;
    Map<String, dynamic>? bestEntry;

    for (var doc in workoutsSnapshot.docs) {
      Timestamp? ts = doc['timestamp'];
      DateTime workoutDate = ts != null ? ts.toDate() : DateTime.now();
      List exercises = doc['exercises'] ?? [];

      for (var ex in exercises) {
        if (ex['id'] == exerciseId) {
          double volume = 0.0;
          List sets = ex['sets'] ?? [];
          for (var set in sets) {
            if (set.containsKey('weight') && set.containsKey('reps')) {
              double wVal = 0.0;
              int repsVal = 0;
              if (set['weight'] is int) {
                wVal = (set['weight'] as int).toDouble();
              } else if (set['weight'] is double) {
                wVal = set['weight'];
              }
              if (set['reps'] is int) {
                repsVal = set['reps'];
              } else {
                repsVal = int.tryParse(set['reps']?.toString() ?? "") ?? 0;
              }
              volume += (wVal * repsVal);
            }
          }
          final entry = {
            'date': workoutDate,
            'volume': volume,
            'sets': sets,
          };
          allEntries.add(entry);
          if (volume > maxVolume) {
            maxVolume = volume;
            bestEntry = entry;
          }
        }
      }
    }

    allEntries.sort((a, b) => b['date'].compareTo(a['date']));
    if (bestEntry != null) {
      allEntries.remove(bestEntry);
    }
    final recent = allEntries.take(10).toList();

    return {
      'bestEntry': bestEntry,
      'recent': recent,
    };
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry, {bool showTrophy = false}) {
    return Consumer<UnitProvider>(
      builder: (context, unitProvider, child) {
        DateTime date = entry['date'];
        double volume = entry['volume'] ?? 0.0;
        if (unitProvider.useMetric) {
          volume = UnitConverter.lbsToKg(volume);
        }
        List sets = entry['sets'] ?? [];
        String unitLabel = unitProvider.useMetric ? 'kg' : 'lbs';

        String setDetails = sets.asMap().entries.map((e) {
          int setNum = e.key + 1;
          var set = e.value;
          double rawWeight = 0.0;
          if (set.containsKey('weight')) {
            if (set['weight'] is int) {
              rawWeight = (set['weight'] as int).toDouble();
            } else if (set['weight'] is double) {
              rawWeight = set['weight'];
            }
          }
          int repsVal = 0;
          if (set.containsKey('reps')) {
            if (set['reps'] is int) {
              repsVal = set['reps'];
            } else {
              repsVal = int.tryParse(set['reps']?.toString() ?? "") ?? 0;
            }
          }
          if (unitProvider.useMetric) {
            rawWeight = UnitConverter.lbsToKg(rawWeight);
          }
          String weightStr =
          rawWeight == 0.0 ? "-" : rawWeight.toStringAsFixed(1);
          return "Set $setNum: $weightStr$unitLabel x $repsVal reps";
        }).join("\n");

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: Theme.of(context).cardColor,
          child: ListTile(
            leading: showTrophy
                ? const Icon(Icons.emoji_events, color: Colors.amber)
                : null,
            title: Text(
              "${date.toLocal().toString().split('.')[0]}",
              style: (Theme.of(context).textTheme.bodyMedium ??
                  const TextStyle())
                  .copyWith(
                  color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Volume: ${volume.toStringAsFixed(1)} $unitLabel",
                  style: (Theme.of(context).textTheme.bodySmall ??
                      const TextStyle())
                      .copyWith(color: Theme.of(context).hintColor),
                ),
                Text(
                  setDetails,
                  style: (Theme.of(context).textTheme.bodySmall ??
                      const TextStyle())
                      .copyWith(color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExerciseHistoryForExercise(Map<String, dynamic> exercise) async {
    final exerciseId = exercise['id'];
    if (exerciseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exercise ID not available.")),
      );
      return;
    }

    final data = await _fetchExerciseHistory(exerciseId);
    final bestEntry = data['bestEntry'] as Map<String, dynamic>?;
    final recent = data['recent'] as List<Map<String, dynamic>>;

    if (bestEntry == null && recent.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Exercise History for ${exercise['name']}"),
          content: const Text("No history found for this exercise."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Exercise History for ${exercise['name']}"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bestEntry != null) ...[
                  const Text(
                    "Personal Best",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  _buildHistoryCard(bestEntry, showTrophy: true),
                  const SizedBox(height: 20),
                ],
                const Text(
                  "Recent History",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (recent.isEmpty)
                  const Text("No recent entries.")
                else
                  for (var entry in recent) _buildHistoryCard(entry),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Workout Session',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.timer, color: primaryColor),
                    onPressed: _showTopTimerDialog,
                    tooltip: "Show Timer Popup",
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _topTimerNotifier,
                    builder: (context, value, child) {
                      return Text(
                        _formatMMSS(value),
                        style: const TextStyle(fontSize: 16),
                      );
                    },
                  ),
                ],
              ),
            ),
            Text(
              "Duration: ${_formatDuration(_duration)}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Workout name & description
            TextField(
              decoration: const InputDecoration(
                labelText: 'Workout Name',
              ),
              controller: _workoutNameController,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
              controller: _workoutDescriptionController,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openExerciseSelection,
              child: const Text('Add Exercise'),
            ),
            const SizedBox(height: 8),
            // List of selected exercises
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _selectedExercises.length,
                itemBuilder: (context, exerciseIndex) {
                  var exercise = _selectedExercises[exerciseIndex];
                  exercise['sets'] ??= [];
                  exercise['controllers'] ??= [];
                  exercise['focusNodes'] ??= [];

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    // Slightly smaller vertical margin
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ), // Tighter padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row: exercise name, add set, remove exercise
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _showExerciseHistoryForExercise(
                                    exercise,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise['name'] ?? 'Unnamed Exercise',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${exercise['category'] ?? 'Unknown Category'} | ${exercise['bodyPart'] ?? 'Unknown Body Part'}"
                                            "${exercise['subcategory'] != null ? ' (${exercise['subcategory']})' : ''}",
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.green),
                                onPressed: () => _addSet(exerciseIndex),
                                tooltip: '+ Another Set',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeExercise(exerciseIndex),
                                tooltip: 'Remove Exercise',
                              ),
                            ],
                          ),
                          // All sets for this exercise
                          Column(
                            children: List.generate(
                              exercise['sets'].length,
                                  (setIndex) {
                                var set = exercise['sets'][setIndex];
                                Map<String, TextEditingController> controllers =
                                exercise['controllers'][setIndex];
                                Map<String, FocusNode> focusNodes =
                                exercise['focusNodes'][setIndex];

                                final bool isComplete =
                                (set['isSetComplete'] == true);

                                final hasReps = set.containsKey('reps');
                                final hasWeight = set.containsKey('weight');
                                final hasDistance = set.containsKey('distance');
                                final hasDuration = set.containsKey('duration');

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: isComplete
                                      ? BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    border: Border.all(
                                      color:
                                      primaryColor.withOpacity(0.4),
                                      width: 1,
                                    ),
                                    borderRadius:
                                    BorderRadius.circular(6),
                                  )
                                      : null,
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Row for checkbox, set #, add/remove set
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: set['isSetComplete'] ?? false,
                                                onChanged: (val) =>
                                                    _onSetCheckChanged(
                                                        exerciseIndex,
                                                        setIndex,
                                                        val),
                                                visualDensity:
                                                VisualDensity.compact,
                                              ),
                                              Text(
                                                "Set ${setIndex + 1}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.add,
                                                    color: Colors.green),
                                                onPressed: () =>
                                                    _addSet(exerciseIndex),
                                                tooltip: '+ Another Set',
                                                visualDensity:
                                                VisualDensity.compact,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.remove,
                                                    color: Colors.red),
                                                onPressed: () => _removeSet(
                                                    exerciseIndex, setIndex),
                                                tooltip: 'Remove This Set',
                                                visualDensity:
                                                VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      // Slight spacing before fields
                                      const SizedBox(height: 4),

                                      // 2 rows for fields
                                      // Row 1: Reps + Weight
                                      // Row 2: Distance + Duration
                                      Column(
                                        children: [
                                          // If we have reps or weight
                                          if (hasReps || hasWeight)
                                            Row(
                                              children: [
                                                if (hasReps)
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                      controllers['reps'],
                                                      focusNode:
                                                      focusNodes['reps'],
                                                      keyboardType:
                                                      TextInputType.number,
                                                      onSubmitted: (value) {
                                                        _verifyAndUpdateReps(
                                                          exerciseIndex,
                                                          setIndex,
                                                          value,
                                                        );
                                                      },
                                                      // Compact styling:
                                                      decoration:
                                                      InputDecoration(
                                                        labelText: "Reps",
                                                        isDense: true,
                                                        contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          vertical: 6,
                                                          horizontal: 8,
                                                        ),
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                if (hasReps && hasWeight)
                                                  const SizedBox(width: 8),
                                                if (hasWeight)
                                                  Expanded(
                                                    child: Consumer<UnitProvider>(
                                                      builder: (context,
                                                          unitProvider, child) {
                                                        return TextField(
                                                          controller:
                                                          controllers[
                                                          'weight'],
                                                          focusNode: focusNodes[
                                                          'weight'],
                                                          keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                          onSubmitted: (value) {
                                                            _verifyAndUpdateWeight(
                                                              exerciseIndex,
                                                              setIndex,
                                                              value,
                                                            );
                                                          },
                                                          decoration:
                                                          InputDecoration(
                                                            labelText: unitProvider
                                                                .useMetric
                                                                ? "Wt (kg)"
                                                                : "Wt (lbs)",
                                                            isDense: true,
                                                            contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                              vertical: 6,
                                                              horizontal: 8,
                                                            ),
                                                          ),
                                                          style:
                                                          const TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          // Spacing if we have a second row
                                          if ((hasReps || hasWeight) &&
                                              (hasDistance || hasDuration))
                                            const SizedBox(height: 6),
                                          // Row 2: Distance + Duration
                                          if (hasDistance || hasDuration)
                                            Row(
                                              children: [
                                                if (hasDistance)
                                                  Expanded(
                                                    child: Consumer<UnitProvider>(
                                                      builder: (context,
                                                          unitProvider, child) {
                                                        return TextField(
                                                          controller:
                                                          controllers[
                                                          'distance'],
                                                          focusNode: focusNodes[
                                                          'distance'],
                                                          keyboardType:
                                                          const TextInputType
                                                              .numberWithOptions(
                                                              decimal: true),
                                                          onSubmitted: (value) {
                                                            _verifyAndUpdateDistance(
                                                              exerciseIndex,
                                                              setIndex,
                                                              value,
                                                            );
                                                          },
                                                          decoration:
                                                          InputDecoration(
                                                            labelText:
                                                            unitProvider
                                                                .useMetric
                                                                ? "Dist (km)"
                                                                : "Dist (mi)",
                                                            isDense: true,
                                                            contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                              vertical: 6,
                                                              horizontal: 8,
                                                            ),
                                                          ),
                                                          style:
                                                          const TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                if (hasDistance && hasDuration)
                                                  const SizedBox(width: 8),
                                                if (hasDuration)
                                                  Expanded(
                                                    child: TextField(
                                                      keyboardType:
                                                      TextInputType.number,
                                                      onChanged: (value) {
                                                        _updateDuration(
                                                          exerciseIndex,
                                                          setIndex,
                                                          int.tryParse(value) ??
                                                              0,
                                                        );
                                                      },
                                                      decoration:
                                                      const InputDecoration(
                                                        labelText: "Time (sec)",
                                                        isDense: true,
                                                        contentPadding:
                                                        EdgeInsets
                                                            .symmetric(
                                                          vertical: 6,
                                                          horizontal: 8,
                                                        ),
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                        ],
                                      ),

                                      // If rest is active, show rest timer
                                      if (set['isRestActive'] == true)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                                children: [
                                                  Text(
                                                    "Rest: ${_formatRestMMSS(set['restRemaining'] as int)}",
                                                    style: TextStyle(
                                                      color: primaryColor,
                                                      fontWeight:
                                                      FontWeight.w600,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      TextButton(
                                                        style:
                                                        TextButton.styleFrom(
                                                          padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 4),
                                                          minimumSize:
                                                          Size.zero,
                                                          tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                          foregroundColor:
                                                          primaryColor,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            final curr =
                                                            set['restRemaining']
                                                            as int;
                                                            final total =
                                                            set['restTotal']
                                                            as int;
                                                            set['restRemaining'] =
                                                                curr + 30;
                                                            set['restTotal'] =
                                                                total + 30;
                                                          });
                                                        },
                                                        child:
                                                        const Text("+30s"),
                                                      ),
                                                      TextButton(
                                                        style:
                                                        TextButton.styleFrom(
                                                          padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 4),
                                                          minimumSize:
                                                          Size.zero,
                                                          tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                          foregroundColor:
                                                          primaryColor,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            final curr =
                                                            set['restRemaining']
                                                            as int;
                                                            final total =
                                                            set['restTotal']
                                                            as int;
                                                            set['restRemaining'] =
                                                                max<int>(0,
                                                                    curr - 30);
                                                            set['restTotal'] =
                                                                max<int>(0,
                                                                    total - 30);
                                                          });
                                                        },
                                                        child:
                                                        const Text("-30s"),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              LinearProgressIndicator(
                                                value: (set['restTotal'] != null &&
                                                    (set['restTotal'] as int) >
                                                        0)
                                                    ? (set['restRemaining']
                                                as int) /
                                                    (set['restTotal'] as int)
                                                    : 0.0,
                                                minHeight: 4,
                                                color: primaryColor,
                                                backgroundColor:
                                                primaryColor.withOpacity(0.2),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Finish/Cancel buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _finishWorkout,
                  child: const Text('Finish Workout'),
                ),
                ElevatedButton(
                  onPressed: _cancelWorkout,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Cancel Workout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _topTimer?.cancel();
    _topTimerNotifier.dispose();
    _workoutNameController.dispose();
    _workoutDescriptionController.dispose();

    for (var exercise in _selectedExercises) {
      if (exercise['controllers'] != null) {
        for (var ctrlMap in exercise['controllers']) {
          ctrlMap.values.forEach((c) => c.dispose());
        }
      }
      if (exercise['focusNodes'] != null) {
        for (var nodeMap in exercise['focusNodes']) {
          nodeMap.values.forEach((node) => node.dispose());
        }
      }
      if (exercise['sets'] is List) {
        for (var setMap in exercise['sets']) {
          if (setMap['restTimer'] != null) {
            (setMap['restTimer'] as Timer).cancel();
          }
        }
      }
    }
    super.dispose();
  }
}
