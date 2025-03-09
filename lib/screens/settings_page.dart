import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart'; // adjust the path as needed

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    // Determine if the current theme is dark
    final bool isDarkMode = themeProvider.currentTheme == ThemeMode.dark;

    return Scaffold(
      // Use the current theme's scaffold background color
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Settings',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading:
            Icon(Icons.account_circle, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Account Settings',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading:
            Icon(Icons.notifications, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Notification Preferences',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Privacy Settings',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.color_lens, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Appearance & Theme',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: Switch(
              value: isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
            ),
            onTap: () {
              // Optionally toggle theme on tap as well
              themeProvider.toggleTheme();
            },
          ),
          Divider(color: Colors.white24),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Logout',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
