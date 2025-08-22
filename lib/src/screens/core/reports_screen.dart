// reports_screen.dart
import 'package:flutter/material.dart';

class ReportsScreen extends StatelessWidget {
  final bool isAdmin;
  const ReportsScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text('${isAdmin ? 'Admin' : 'Driver'} Reports'),
      ),
      body: Center(
        child: Text('${isAdmin ? 'Admin' : 'Driver'} Reports Screen'),
      ),
    );
  }
}