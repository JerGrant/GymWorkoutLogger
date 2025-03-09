import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  bool _isLoading = false;
  String? _errorMessage;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled sign-in
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = _auth.currentUser;

      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists || !doc.data()!.containsKey('progressPictures')) {
          _promptUploadPicture(user.uid);
        }
      }
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _promptUploadPicture(String userId) async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
              title: Text("Take a Picture", style: Theme.of(context).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _pickImage(userId, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: Text("Choose from Gallery", style: Theme.of(context).textTheme.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _pickImage(userId, ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(String userId, ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);

    try {
      String filePath = 'progress_pictures/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      TaskSnapshot snapshot = await _storage.ref(filePath).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _db.collection('users').doc(userId).set({
        'progressPictures': FieldValue.arrayUnion([{
          'url': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'caption': ''
        }])
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error uploading progress picture: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Updated from hardcoded Color(0xFF000015)
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Blue Dumbbell Image
                Image.asset(
                  'lib/assets/BlueDumbbell.png', // Ensure this file exists in your assets
                  height: 120, // Adjust size as needed
                ),
                SizedBox(height: 20),
                // Welcome Text
                Text(
                  'Welcome Back to [APP NAME]!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                  ),
                ),
                SizedBox(height: 20),
                // Error Message (If any)
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 10),
                // Google Sign-In Button
                _isLoading
                    ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                    : ElevatedButton(
                  onPressed: _signInWithGoogle,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login, color: Theme.of(context).colorScheme.onPrimary),
                      SizedBox(width: 10),
                      Text('Sign In with Google'),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary, // Updated Button Color
                    foregroundColor: Theme.of(context).colorScheme.onPrimary, // Text/Icon color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30), // Rounded button
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
