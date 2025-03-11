import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UnitProvider with ChangeNotifier {
  bool _isKg = false;
  bool get isKg => _isKg;

  UnitProvider() {
    loadUnitPreference();
  }

  Future<void> loadUnitPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      _isKg = doc.data()?['unitPreference'] == 'kg';
      notifyListeners();
    }
  }

  Future<void> updateUnitPreference(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'unitPreference': value ? 'kg' : 'lbs',
      });
      _isKg = value;
      notifyListeners();
    }
  }
}
