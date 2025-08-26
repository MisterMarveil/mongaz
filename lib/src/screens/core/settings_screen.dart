// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/contants.dart';

final settingsProvider = FutureProvider<AppSettings>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return AppSettings.fromPreferences(prefs);
});

class AppSettings {
  final bool autoAssignOrders;
  final List<String> defaultDriverIds;

  AppSettings({required this.autoAssignOrders, required this.defaultDriverIds});

  factory AppSettings.fromPreferences(SharedPreferences prefs) {
    return AppSettings(
      autoAssignOrders: prefs.getBool('autoAssignOrders') ?? false,
      defaultDriverIds: prefs.getStringList('defaultDriverIds') ?? [],
    );
  }

  Future<void> saveToPreferences(SharedPreferences prefs) async {
    await prefs.setBool('autoAssignOrders', autoAssignOrders);
    await prefs.setStringList('defaultDriverIds', defaultDriverIds);
  }
}

class SettingsScreen extends ConsumerWidget {
  final bool isAdmin;
  const SettingsScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSecondaryBarBackgroundColor,
        title: Text('${isAdmin ? 'Admin' : 'Driver'} Settings',
            style: kSecondaryBarStyle),
      ),
      body: settingsAsync.when(
        data: (settings) => ListView(
          children: [
            if (isAdmin) ...[
              SwitchListTile(
                title: const Text('Automatic Order Assignment'),
                value: settings.autoAssignOrders,
                onChanged: (value) async {
                  final prefs = await SharedPreferences.getInstance();
                  final newSettings = AppSettings(
                    autoAssignOrders: value,
                    defaultDriverIds: settings.defaultDriverIds,
                  );
                  await newSettings.saveToPreferences(prefs);
                  ref.invalidate(settingsProvider);
                },
              ),
              if (settings.autoAssignOrders)
                ListTile(
                  title: const Text('Default Drivers'),
                  subtitle: Text(
                      '${settings.defaultDriverIds.length} drivers selected'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to driver selection screen
                  },
                ),
              const Divider(),
            ],
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
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Se Déconnecter'),
              onTap: () {
                // Navigate to instructions screen
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}