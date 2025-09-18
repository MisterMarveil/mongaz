import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2)); // small splash delay
    final token = await _storage.read(key: 'access_token');
    final role = await _storage.read(key: 'user_role'); // e.g., 'admin' or 'driver'
    if (token != null && role != null) {
      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, Routes.adminOrders);
      } else if (role == 'driver') {
        Navigator.pushReplacementNamed(context, Routes.driverHome);
      } else {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
    } else {
      Navigator.pushReplacementNamed(context, Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeigth = MediaQuery.of(context).size.height;
    double logoHeight = screenHeigth * 0.25; // 30% of screen height

    return Scaffold(
      body: Center(
        child: Column(
          children: [
            SizedBox(height: (screenHeigth / 2) - (logoHeight / 2) - 10), // Adjust height as needed
            Image(image: const AssetImage('assets/images/logo.png'),height: logoHeight,),
          ],
        ),
      ),
    );
  }
}
