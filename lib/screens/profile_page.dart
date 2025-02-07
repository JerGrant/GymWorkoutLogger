import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _user;

  int workoutStreak = 0;
  String name = "User Name";
  String location = "Not Set";
  double height = 0.0;
  double weight = 0.0;
  String profileImage = "https://via.placeholder.com/150";

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  Future<void> _getUser() async {
    final user = await _googleSignIn.signInSilently();
    if (user != null) {
      setState(() {
        _user = user;
        name = user.displayName ?? "User Name";
        profileImage = user.photoUrl ?? "https://via.placeholder.com/150";
      });
    }
  }

  void _editProfile() {
    // Placeholder for edit profile function
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(profileImage),
            ),
            SizedBox(height: 10),
            Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Location: $location"),
            Text("Height: ${height.toStringAsFixed(1)} cm"),
            Text("Weight: ${weight.toStringAsFixed(1)} kg"),
            SizedBox(height: 20),
            Text("Workout Streak: $workoutStreak days", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _editProfile,
              child: Text("Edit Profile"),
            ),
            SizedBox(height: 20),
            Text("Achievements & Challenges", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView(
                children: [
                  ListTile(leading: Icon(Icons.star), title: Text("First Workout Logged")),
                  ListTile(leading: Icon(Icons.local_fire_department), title: Text("5-Day Streak")),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
