import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:lottie/lottie.dart';
import 'package:punyadaan/routes/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _initApp();
  }

  Future<void> _initApp() async {
    // Let the splash animation render for at least one frame
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    // Navigate to auth gate — permissions are requested after login
    Navigator.of(context).pushReplacementNamed(AppRouter.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/splash_animation.json',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}