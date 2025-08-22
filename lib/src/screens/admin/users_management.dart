// users_management.dart
import 'package:flutter/material.dart';

class UsersManagementScreen extends StatelessWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Users Management'),
      ),
      body: const Center(
        child: Text('Users Management Screen'),
      ),
    );
  }
}