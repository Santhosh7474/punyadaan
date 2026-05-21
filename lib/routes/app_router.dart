import 'package:flutter/material.dart';
import 'package:punyadaan/auth/auth_gate.dart';
import 'package:punyadaan/auth/login_screen.dart';
import 'package:punyadaan/auth/role_selection_screen.dart';
import 'package:punyadaan/home/donator_home_page.dart';
import 'package:punyadaan/home/donee_home_page.dart';
import 'package:punyadaan/splash/splash_screen.dart';

class AppRouter {
  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String login = '/login';
  static const String home = '/home';
  static const String doneeHome = '/doneeHome';
  static const String roleSelection = '/roleSelection';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case auth:
        return MaterialPageRoute(builder: (_) => const AuthGate());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const DemoHomePage());
      case doneeHome:
        return MaterialPageRoute(builder: (_) => const DoneeHomePage());
      case roleSelection:
        return MaterialPageRoute(builder: (_) => const RoleSelectionScreen());
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
