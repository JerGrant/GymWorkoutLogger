import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// UnitProvider manages whether the user wants metric or imperial units.
/// A single boolean (_useMetric) controls all unit conversions.
class UnitProvider with ChangeNotifier {
  bool _useMetric = false;
  bool get useMetric => _useMetric;

  UnitProvider() {
    loadUnitPreference();
  }

  Future<void> loadUnitPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?.containsKey('unitPreference') == true) {
        _useMetric = doc.data()!['unitPreference'] == 'metric';
      } else {
        _useMetric = false;
      }
      notifyListeners();
    }
  }

  Future<void> updateUnitPreference(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'unitPreference': value ? 'metric' : 'imperial',
      });
      _useMetric = value;
      notifyListeners();
    }
  }
}
