import 'package:flutter/material.dart';
import 'routes.dart';
import 'src/services/network_service.dart';
import 'src/screens/core/network_aware_wrapper.dart';
import 'package:provider/provider.dart';

class MongazApp extends StatelessWidget {
  const MongazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NetworkService(),
      child: MaterialApp(
        title: 'MONGAZ',
        theme: ThemeData(primarySwatch: Colors.teal, fontFamily: "Sora"),
        initialRoute: Routes.splash,
        routes: Routes.routes,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
