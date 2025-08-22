// earnings_screen.dart
import 'package:flutter/material.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: const Text('Earnings'),
      ),
      body: const Center(
        child: Text('Earnings Screen - Daily summary and statistics (performances)'),
      ),
    );
  }
}