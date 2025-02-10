import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addExercise(String name, String category, String bodyPart, String description) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Ensure the user is logged in

    final userId = user.uid;
    final exerciseRef = _firestore.collection('users').doc(userId).collection('exercises');

    await exerciseRef.add({
      'name': name,
      'category': category,
      'bodyPart': bodyPart,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getUserExercises() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]); // Return empty list if no user
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('exercises')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<void> deleteExercise(String exerciseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final exerciseRef = _firestore.collection('users').doc(user.uid).collection('exercises').doc(exerciseId);
    await exerciseRef.delete();
  }
}
