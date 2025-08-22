// settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  final bool isAdmin;
  const SettingsScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text('${isAdmin ? 'Admin' : 'Driver'} Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('User Information'),
            onTap: () {
              // Navigate to user info screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notification Settings'),
            onTap: () {
              // Navigate to notification settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: () {
              // Navigate to change password screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Instructions'),
            onTap: () {
              // Navigate to instructions screen
            },
          ),
        ],
      ),
    );
  }
}