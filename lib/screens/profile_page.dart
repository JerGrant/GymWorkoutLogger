import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gymworkoutlogger/screens/settings_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ProfilePage extends StatefulWidget {
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

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _feetController = TextEditingController();
  final TextEditingController _inchesController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

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
          _weightController.text = weight.toString();
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  Future<void> _uploadProfileImage() async {
    if (!isEditing) return; // Only allow changing image in edit mode
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
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
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    File file = File(pickedFile.path);
    // Prompt user for a caption or notes
    String? caption = await showDialog<String>(
      context: context,
      builder: (context) {
        final TextEditingController _captionController =
        TextEditingController();
        return AlertDialog(
          title: Text("Enter Caption/Notes"),
          content: TextField(
            controller: _captionController,
            decoration: InputDecoration(hintText: "Caption or notes"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel => null
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(_captionController.text),
              child: Text("Save"),
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
        SnackBar(content: Text("Progress picture uploaded!")),
      );
    } catch (e) {
      print("Error uploading progress picture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading progress picture.")),
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
      await _db.collection('users').doc(_user!.uid).set({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'city': _cityController.text,
        'state': selectedState,
        'feet': int.tryParse(_feetController.text) ?? 0,
        'inches': int.tryParse(_inchesController.text) ?? 0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
          SnackBar(
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
        if (snapshot.hasError)
          return Text("Error loading progress pictures.");
        if (snapshot.connectionState == ConnectionState.waiting)
          return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return Text("No progress pictures uploaded yet.");
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                ? DateTime.fromMillisecondsSinceEpoch(
                timestamp.millisecondsSinceEpoch)
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
                      style: TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      timeString,
                      style: TextStyle(fontSize: 10, color: Colors.grey),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$firstName $lastName",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text("$city, $selectedState"),
        SizedBox(height: 6),
        Text("Height: $feet' $inches\""),
        SizedBox(height: 6),
        Text("Weight: $weight lbs"),
      ],
    );
  }

  /// Displays the full editable fields when in edit mode.
  Widget _buildEditableFields() {
    return Column(
      children: [
        TextField(
          controller: _firstNameController,
          decoration: InputDecoration(labelText: "First Name"),
        ),
        TextField(
          controller: _lastNameController,
          decoration: InputDecoration(labelText: "Last Name"),
        ),
        TextField(
          controller: _cityController,
          decoration: InputDecoration(labelText: "City"),
        ),
        IgnorePointer(
          ignoring: !isEditing,
          child: DropdownButton<String>(
            value: selectedState,
            items: states.map((state) {
              return DropdownMenuItem(value: state, child: Text(state));
            }).toList(),
            onChanged: (value) {
              setState(() => selectedState = value!);
            },
          ),
        ),
        TextField(
          controller: _feetController,
          decoration: InputDecoration(labelText: "Feet"),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _inchesController,
          decoration: InputDecoration(labelText: "Inches"),
          keyboardType: TextInputType.number,
        ),
        TextField(
          controller: _weightController,
          decoration: InputDecoration(labelText: "Weight (lbs)"),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // Method to display the full profile image in a dialog.
  void _showFullImage() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(10),
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
      backgroundColor: Color(0xFF000015), // Set background color
      appBar: AppBar(
        backgroundColor: Color(0xFF000015), // Set app bar color to match
        automaticallyImplyLeading: false, // Removes the back arrow
        title: Text("Profile", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Color(0xFF007AFF)), // Change settings icon to blue
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
            ),
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit, color: Color(0xFF007AFF)), // Change edit icon to blue
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
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile image: tap to change in edit mode, or display full image otherwise.
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
            SizedBox(height: 10),
            if (isEditing) Text("Tap to change profile image"),
            SizedBox(height: 20),
            isEditing ? _buildEditableFields() : _buildReadOnlyFields(),
            SizedBox(height: 30),
            Divider(),
            // Progress Pictures section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progress Pictures",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text("Sort: "),
                    DropdownButton<bool>(
                      value: _isNewestFirst,
                      items: [
                        DropdownMenuItem(
                          child: Text("Newest to Oldest"),
                          value: true,
                        ),
                        DropdownMenuItem(
                          child: Text("Oldest to Newest"),
                          value: false,
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
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _uploadProgressPicture,
              icon: Icon(Icons.upload, color: Colors.white),
              label: Text("Upload Progress Picture"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF007AFF), // Set button color to blue
                foregroundColor: Colors.white, // Ensure text/icon is white
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Slightly rounded edges
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
            SizedBox(height: 10),
            _buildProgressPicturesGallery(),
          ],
        ),
      ),
    );
  }
}
