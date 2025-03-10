// theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // default to system if nothing stored

  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeMode get currentTheme => _themeMode;

  // Toggle between light and dark modes, then save
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
    await _saveThemePreference();
  }

  // Explicitly set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _saveThemePreference();
  }

  // Save the user's current theme mode to SharedPreferences
  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('themeMode', _themeMode.toString().split('.').last);
  }

  // Load the user's theme mode from SharedPreferences
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString('themeMode');
    if (storedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (storedMode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }
}
