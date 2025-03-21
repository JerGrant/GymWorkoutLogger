import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../providers/unit_provider.dart';
import '../providers/accessibility_provider.dart'; // <-- import the new provider

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDarkMode = themeProvider.currentTheme == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            leading: Icon(Icons.account_circle, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Account Settings',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(Icons.notifications, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Notification Preferences',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(Icons.privacy_tip, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Privacy Settings',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(Icons.brightness_6, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Light / Dark Mode',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            trailing: Switch(
              value: isDarkMode,
              onChanged: (_) {
                themeProvider.toggleTheme();
              },
            ),
          ),
          Divider(color: Theme.of(context).dividerColor),
          Consumer<UnitProvider>(
            builder: (context, unitProvider, _) {
              return ListTile(
                leading: Icon(Icons.fitness_center, color: Theme.of(context).iconTheme.color),
                title: Text(
                  'Use Metric instead of Imperial',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: Switch(
                  value: unitProvider.useMetric,
                  onChanged: (value) {
                    unitProvider.updateUnitPreference(value);
                  },
                ),
              );
            },
          ),
          Divider(color: Theme.of(context).dividerColor),
          // New Accessibility Toggle
          Consumer<AccessibilityProvider>(
            builder: (context, accessibilityProvider, _) {
              return ListTile(
                leading: Icon(Icons.accessibility, color: Theme.of(context).iconTheme.color),
                title: Text(
                  'Enable Large Text Mode',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: Switch(
                  value: accessibilityProvider.isLargeText,
                  onChanged: (value) {
                    accessibilityProvider.toggleLargeText(value);
                  },
                ),
              );
            },
          ),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).iconTheme.color),
            title: Text(
              'Logout',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {},
          ),
          Divider(color: Theme.of(context).dividerColor),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Are you sure?'),
                  content: const Text(
                    'This action cannot be undone. Are you sure you want to delete your account permanently?',
                    style: TextStyle(color: Colors.red),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () {
                        // Implement delete account logic here
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
