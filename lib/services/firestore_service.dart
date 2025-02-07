import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the current user's Firestore document reference
  DocumentReference get userDocRef {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return _db.collection('users').doc(user.uid);
  }

  /// Fetch user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    final doc = await userDocRef.get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  /// Save or update user profile
  Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    await userDocRef.set(profileData, SetOptions(merge: true));
  }
}
