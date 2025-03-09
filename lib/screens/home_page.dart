import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'workout_page.dart';
import 'exercise_page.dart'; // Import Exercise Page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePageContent(),
    WorkoutPage(),
    ExercisePage(), // Added Exercise Page
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use themed scaffold background
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Instead of Color(0xFF000015)
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        // Use themed background color
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Instead of Color(0xFF000015)
        selectedItemColor: Theme.of(context).colorScheme.primary, // Instead of Color(0xFF007AFF)
        // Using onSurface with opacity for unselected color
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), // Instead of Colors.blue.shade200
        type: BottomNavigationBarType.fixed, // Prevents shifting effect
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list), // Exercises icon
            label: 'Exercises',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Extracting Home Page UI to Keep Code Clean
class HomePageContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // Use themed scaffold background
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Instead of Color(0xFF000015)
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back arrow
        // Use themed AppBar background
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, // Instead of Color(0xFF000015)
        title: Text(
          'Welcome, ${user?.displayName ?? "User"}',
          // Use themed text style (if defined) or fallback to default
          style: Theme.of(context).appBarTheme.titleTextStyle ?? TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          IconButton(
            // Use themed error color for logout if desired
            icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error), // Instead of Colors.red
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          'You are signed in!',
          style: Theme.of(context).textTheme.bodyMedium, // Instead of TextStyle(color: Colors.white)
        ),
      ),
    );
  }
}
