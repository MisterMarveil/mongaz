import 'package:flutter/widgets.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/admin/orders_list.dart';
import 'src/screens/driver/driver_home.dart';
import 'src/screens/splash.dart';

class Routes {
  static const splash = '/';
  static const login = '/login';
  static const adminOrders = '/admin/orders';
  static const driverHome = '/driver/home';

  static final routes = <String, WidgetBuilder>{
    splash: (c) => const SplashScreen(),
    login: (c) => const LoginScreen(),
    adminOrders: (c) => const AdminOrdersList(),
    driverHome: (c) => const DriverHome(),
  };
}
