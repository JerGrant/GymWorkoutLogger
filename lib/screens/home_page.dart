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
      backgroundColor: Color(0xFF000015), // Ensure middle matches top & bottom
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF000015), // Matches AppBar and body
        selectedItemColor: Color(0xFF007AFF), // iOS blue for selected item
        unselectedItemColor: Colors.blue.shade200, // Lighter blue for unselected
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
      backgroundColor: Color(0xFF000015), // Matches dark theme
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back arrow
        backgroundColor: Color(0xFF000015), // Matches dark theme
        title: Text(
          'Welcome, ${user?.displayName ?? "User"}',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red), // Logout button in red
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
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
