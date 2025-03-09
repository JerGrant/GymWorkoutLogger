import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000015), // Dark background color
      appBar: AppBar(
        backgroundColor: Color(0xFF000015), // Match background
        surfaceTintColor: Colors.transparent, // Disable surface tint
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white), // White title text
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: Icon(Icons.account_circle, color: Colors.white),
            title: Text('Account Settings', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.notifications, color: Colors.white),
            title: Text('Notification Preferences', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: Colors.white),
            title: Text('Privacy Settings', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.color_lens, color: Colors.white),
            title: Text('Appearance & Theme', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.white),
            title: Text('Logout', style: TextStyle(color: Colors.white)),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
