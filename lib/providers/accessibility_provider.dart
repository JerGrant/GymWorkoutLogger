import 'package:flutter/material.dart';

class AccessibilityProvider with ChangeNotifier {
  bool _isLargeText = false;

  bool get isLargeText => _isLargeText;

  void toggleLargeText(bool value) {
    _isLargeText = value;
    notifyListeners();
  }
}
