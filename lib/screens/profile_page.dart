import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gymworkoutlogger/screens/settings_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:gymworkoutlogger/providers/unit_provider.dart';
import 'package:gymworkoutlogger/utils/unit_converter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _user;

  // Placeholder image if Firestore doesn't have a profileImage
  String profileImage = "lib/assets/prog-pic.jpg";

  String firstName = "";
  String lastName = "";
  String city = "";
  String selectedState = "Select State";
  int feet = 0;
  int inches = 0;
  double weight = 0.0;

  // For metric display/edit of height:
  double _heightInCm = 0.0;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _feetController = TextEditingController();
  final TextEditingController _inchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // New: Controller for height in cm
  final TextEditingController _cmController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool isEditing = false;

  // Sorting flag for progress pictures: true => newest first
  bool _isNewestFirst = true;

  List<String> states = [
    "Select State",
    "Alabama",
    "Alaska",
    "Arizona",
    "Arkansas",
    "California",
    "Colorado",
    "Connecticut",
    "Delaware",
    "Florida",
    "Georgia",
    "Hawaii",
    "Idaho",
    "Illinois",
    "Indiana",
    "Iowa",
    "Kansas",
    "Kentucky",
    "Louisiana",
    "Maine",
    "Maryland",
    "Massachusetts",
    "Michigan",
    "Minnesota",
    "Mississippi",
    "Missouri",
    "Montana",
    "Nebraska",
    "Nevada",
    "New Hampshire",
    "New Jersey",
    "New Mexico",
    "New York",
    "North Carolina",
    "North Dakota",
    "Ohio",
    "Oklahoma",
    "Oregon",
    "Pennsylvania",
    "Rhode Island",
    "South Carolina",
    "South Dakota",
    "Tennessee",
    "Texas",
    "Utah",
    "Vermont",
    "Virginia",
    "Washington",
    "West Virginia",
    "Wisconsin",
    "Wyoming"
  ];

  @override
  void initState() {
    super.initState();
    _getUser();
  }

  Future<void> _getUser() async {
    setState(() => isLoading = true);
    _user = _auth.currentUser;
    if (_user != null) {
      await _fetchUserProfile(_user!.uid);
    }
    setState(() => isLoading = false);
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
          profileImage = data['profileImage'] ?? "lib/assets/prog-pic.jpg";

          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _cityController.text = city;
          _feetController.text = feet.toString();
          _inchesController.text = inches.toString();

          // Convert lbs → kg if user is in metric mode. For now, just store lbs in DB.
          _weightController.text = weight.toString();

          // Calculate height in cm for display if needed:
          _heightInCm = (feet * 30.48) + (inches * 2.54);
          _cmController.text = _heightInCm.toStringAsFixed(2);
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  Future<void> _uploadProfileImage() async {
    if (!isEditing) return; // Only allow changing image in edit mode
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);
    try {
      String filePath = 'profile_images/${_user!.uid}.jpg';
      TaskSnapshot snapshot = await _storage.ref(filePath).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      await _db.collection('users').doc(_user!.uid).set({
        'profileImage': downloadUrl,
      }, SetOptions(merge: true));
      setState(() {
        profileImage = downloadUrl;
      });
    } catch (e) {
      print("Error uploading profile image: $e");
    }
  }

  Future<void> _uploadProgressPicture() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);
    // Prompt user for a caption or notes
    String? caption = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController _captionController = TextEditingController();
        return AlertDialog(
          title: const Text("Enter Caption/Notes"),
          content: TextField(
            controller: _captionController,
            decoration: const InputDecoration(hintText: "Caption or notes"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel => null
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_captionController.text),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
    if (caption == null) return;
    try {
      String filePath =
          'progress_pictures/${_user!.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      TaskSnapshot snapshot = await _storage.ref(filePath).putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      await _db
          .collection('users')
          .doc(_user!.uid)
          .collection('progressPictures')
          .add({
        'imageUrl': downloadUrl,
        'caption': caption,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Progress picture uploaded!")),
      );
    } catch (e) {
      print("Error uploading progress picture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error uploading progress picture.")),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null) {
      print("No authenticated user found.");
      return;
    }
    setState(() => isSaving = true);
    try {
      // Get the current unit preference.
      final unitProvider = Provider.of<UnitProvider>(context, listen: false);

      // Handle weight first:
      double enteredWeight = double.tryParse(_weightController.text) ?? 0.0;
      if (unitProvider.useMetric) {
        // If user typed in kg, convert to lbs for storage:
        enteredWeight = UnitConverter.kgToLbs(enteredWeight);
      }

      // Handle height:
      int finalFeet = feet;
      int finalInches = inches;

      if (unitProvider.useMetric) {
        // If user typed in cm, convert to feet/inches for storage:
        double cmValue = double.tryParse(_cmController.text) ?? 0.0;
        // totalInches = cm / 2.54
        double totalInches = cmValue / 2.54;
        finalFeet = totalInches ~/ 12;
        finalInches = (totalInches % 12).round();
      } else {
        // If user typed in feet/inches, read from those text fields:
        finalFeet = int.tryParse(_feetController.text) ?? 0;
        finalInches = int.tryParse(_inchesController.text) ?? 0;
      }

      await _db.collection('users').doc(_user!.uid).set({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'city': _cityController.text,
        'state': selectedState,
        'feet': finalFeet,
        'inches': finalInches,
        'weight': enteredWeight, // Always store in lbs
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated successfully!"),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      print("Profile updated successfully!");
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error saving profile. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
      print("Error saving profile: $e");
    }
  }

  Widget _buildProgressPicturesGallery() {
    if (_user == null) return Container();
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(_user!.uid)
          .collection('progressPictures')
          .orderBy('timestamp', descending: _isNewestFirst)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text("Error loading progress pictures.");
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text("No progress pictures uploaded yet.");
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            String imageUrl = data['imageUrl'] ?? "";
            String caption = data['caption'] ?? "";
            Timestamp? timestamp = data['timestamp'] as Timestamp?;
            String timeString = timestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
                .toLocal()
                .toString()
                : "";
            return Card(
              elevation: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: imageUrl.startsWith('http')
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : Container(color: Colors.grey),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      caption,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      timeString,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Displays read-only user info when not editing.
  Widget _buildReadOnlyFields() {
    return Consumer<UnitProvider>(
      builder: (context, unitProvider, child) {
        double displayWeight = unitProvider.useMetric ? UnitConverter.lbsToKg(weight) : weight;
        String weightUnitLabel = unitProvider.useMetric ? "kg" : "lbs";

        // Convert feet/inches to cm if metric:
        String heightText;
        if (unitProvider.useMetric) {
          double cmVal = (feet * 30.48) + (inches * 2.54);
          heightText = "${cmVal.toStringAsFixed(2)} cm";
        } else {
          heightText = "$feet' $inches\"";
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$firstName $lastName",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "$city, $selectedState",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              "Height: $heightText",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              "Weight: ${displayWeight.toStringAsFixed(2)} $weightUnitLabel",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
    );
  }

  /// Displays the full editable fields when in edit mode.
  Widget _buildEditableFields() {
    return Consumer<UnitProvider>(
      builder: (context, unitProvider, child) {
        return Column(
          children: [
            TextField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: "First Name"),
            ),
            TextField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: "Last Name"),
            ),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: "City"),
            ),
            DropdownButton<String>(
              value: selectedState,
              items: states.map((state) {
                return DropdownMenuItem(value: state, child: Text(state));
              }).toList(),
              onChanged: (value) {
                if (isEditing) {
                  setState(() => selectedState = value!);
                }
              },
            ),
            // Now handle height differently depending on unit preference:
            if (!unitProvider.useMetric) ...[
              // Show feet/inches fields
              TextField(
                controller: _feetController,
                decoration: const InputDecoration(labelText: "Feet"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _inchesController,
                decoration: const InputDecoration(labelText: "Inches"),
                keyboardType: TextInputType.number,
              ),
            ] else ...[
              // Show a single text field for cm
              TextField(
                controller: _cmController,
                decoration: const InputDecoration(labelText: "Height (cm)"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
            // Weight field
            TextField(
              controller: _weightController,
              decoration: InputDecoration(
                labelText: "Weight (${unitProvider.useMetric ? 'kg' : 'lbs'})",
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        );
      },
    );
  }

  // Displays the full profile image in a dialog.
  void _showFullImage() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: profileImage.startsWith('http')
                ? Image.network(profileImage, fit: BoxFit.contain)
                : Image.asset(profileImage, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        automaticallyImplyLeading: false,
        title: Text(
          "Profile",
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              isEditing ? Icons.check : Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () async {
              if (isEditing) {
                await _saveProfile();
              }
              setState(() {
                isEditing = !isEditing;
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                if (isEditing) {
                  _uploadProfileImage();
                } else {
                  _showFullImage();
                }
              },
              child: CircleAvatar(
                radius: 50,
                backgroundImage: profileImage.startsWith('http')
                    ? NetworkImage(profileImage)
                    : AssetImage(profileImage) as ImageProvider,
              ),
            ),
            const SizedBox(height: 10),
            if (isEditing)
              Text(
                "Tap to change profile image",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            isEditing ? _buildEditableFields() : _buildReadOnlyFields(),
            const SizedBox(height: 30),
            const Divider(),
            // Use a Wrap so "Progress Pictures" and "Sort" stay on one line
            // in normal text mode, but wrap to the next line in large text mode.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                Text(
                  "Progress Pictures",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Sort: ", style: Theme.of(context).textTheme.bodyMedium),
                    DropdownButton<bool>(
                      value: _isNewestFirst,
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text("Newest to Oldest", style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text("Oldest to Newest", style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _isNewestFirst = value!;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _uploadProgressPicture,
              icon: const Icon(Icons.upload),
              label: const Text("Upload Progress Picture"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            _buildProgressPicturesGallery(),
          ],
        ),
      ),
    );
  }
}
