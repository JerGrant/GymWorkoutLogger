import 'package:flutter/material.dart';

class AppTheme {
  // ---------------------------------------
  // Dark Theme (unchanged)
  // ---------------------------------------
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF000015),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF000015),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    colorScheme: const ColorScheme.dark().copyWith(
      primary: Color(0xFF007AFF), // Accent color
      onPrimary: Colors.white,
      surface: Color(0xFF1A1A2E),
      onSurface: Colors.white,
    ),
    cardColor: const Color(0xFF1A1A2E),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Colors.white70),
    ),
  );

  // ---------------------------------------
  // Light Theme (updated with new palette)
  // ---------------------------------------
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,

    // Slightly off-white background for better contrast than pure white
    scaffoldBackgroundColor: const Color(0xFFF9F9F9),

    // Use a true white for cards/containers to distinguish them from the background
    cardColor: Colors.white,

    // Keep the same accent color for brand consistency
    primaryColor: const Color(0xFF007AFF),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Color(0xFF333333),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Color(0xFF333333)),
    ),

    // Define a color scheme that references your chosen colors
    colorScheme: const ColorScheme.light().copyWith(
      primary: Color(0xFF007AFF),
      onPrimary: Colors.white, // text on primary
      background: Color(0xFFF9F9F9),
      surface: Colors.white,
      onSurface: Color(0xFF333333),
    ),

    // Update the default text colors
    textTheme: const TextTheme(
      // Primary text color
      bodyLarge: TextStyle(color: Color(0xFF333333)),
      bodyMedium: TextStyle(color: Color(0xFF333333)),
      // For secondary or hint text, you can use a medium-gray
      bodySmall: TextStyle(color: Color(0xFF666666)),
    ),

    // You can tweak your ElevatedButtonTheme or other component themes similarly
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
      ),
    ),
  );
}
