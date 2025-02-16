// Updating sign_in_page.dart to include missing _promptUploadPicture method
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
              leading: Icon(Icons.camera_alt),
              title: Text("Take a Picture"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(userId, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Choose from Gallery"),
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
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sign In with Google',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: 10),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _signInWithGoogle,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login),
                    SizedBox(width: 10),
                    Text('Sign In with Google'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
