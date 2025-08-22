import 'package:flutter/material.dart';
import 'routes.dart';

class MongazApp extends StatelessWidget {
  const MongazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MONGAZ',
      theme: ThemeData(primarySwatch: Colors.teal, fontFamily: "Sora"),
      initialRoute: Routes.splash,
      routes: Routes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
