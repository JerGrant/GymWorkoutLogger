import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _user;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  int workoutStreak = 0;
  String firstName = "";
  String lastName = "";
  String city = "";
  String selectedState = "Select State";
  int feet = 0;
  int inches = 0;
  double weight = 0.0;
  String profileImage = "https://via.placeholder.com/150";

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _feetController = TextEditingController();
  final TextEditingController _inchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  bool isLoading = true;

  List<String> states = [
    "Select State", "Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"
  ];

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  Future<void> _getUser() async {
    try {
      final user = await _googleSignIn.signInSilently();
      if (user != null) {
        setState(() {
          _user = user;
          profileImage = user.photoUrl ?? "https://via.placeholder.com/150";
        });
        await _fetchUserProfile(user.id);
      }
    } catch (e) {
      print("Error fetching user: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchUserProfile(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          firstName = data['firstName'] ?? "";
          lastName = data['lastName'] ?? "";
          city = data['city'] ?? "";
          selectedState = data['state'] ?? "Select State";
          feet = data['feet'] ?? 0;
          inches = data['inches'] ?? 0;
          weight = (data['weight'] ?? 0.0).toDouble();
          profileImage = data['profileImage'] ?? "https://via.placeholder.com/150";
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _cityController.text = city;
          _feetController.text = feet.toString();
          _inchesController.text = inches.toString();
          _weightController.text = weight.toString();
        });
      } else {
        print("User profile not found in Firestore.");
      }
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _uploadProfileImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);

    try {
      String filePath = 'profile_images/${_user!.id}.jpg';
      TaskSnapshot snapshot = await _storage.ref(filePath).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _db.collection('users').doc(_user!.id).set({
        'profileImage': downloadUrl,
      }, SetOptions(merge: true));

      setState(() {
        profileImage = downloadUrl;
      });
    } catch (e) {
      print("Error uploading profile image: $e");
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    await _db.collection('users').doc(_user!.id).set({
      'firstName': _firstNameController.text,
      'lastName': _lastNameController.text,
      'city': _cityController.text,
      'state': selectedState,
      'feet': int.tryParse(_feetController.text) ?? 0,
      'inches': int.tryParse(_inchesController.text) ?? 0,
      'weight': double.tryParse(_weightController.text) ?? 0.0,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Profile")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _uploadProfileImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(profileImage),
              ),
            ),
            SizedBox(height: 10),
            Text("Tap to change profile image"),
            TextField(controller: _firstNameController, decoration: InputDecoration(labelText: "First Name")),
            TextField(controller: _lastNameController, decoration: InputDecoration(labelText: "Last Name")),
            TextField(controller: _cityController, decoration: InputDecoration(labelText: "City")),
            DropdownButton<String>(
              value: selectedState,
              items: states.map((state) {
                return DropdownMenuItem(value: state, child: Text(state));
              }).toList(),
              onChanged: (value) {
                setState(() => selectedState = value!);
              },
            ),
            TextField(controller: _feetController, decoration: InputDecoration(labelText: "Feet"), keyboardType: TextInputType.number),
            TextField(controller: _inchesController, decoration: InputDecoration(labelText: "Inches"), keyboardType: TextInputType.number),
            TextField(controller: _weightController, decoration: InputDecoration(labelText: "Weight (lbs)"), keyboardType: TextInputType.number),
            ElevatedButton(onPressed: _saveProfile, child: Text("Save Changes")),
          ],
        ),
      ),
    );
  }
}
