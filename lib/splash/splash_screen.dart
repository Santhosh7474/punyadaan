import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:lottie/lottie.dart';
import 'package:punyadaan/routes/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Do NOT remove native splash here — keep it until Lottie is ready
    // so there is zero white-flash between native splash and animation.
    _controller = AnimationController(vsync: this);
  }

  /// Called once Lottie has parsed the JSON and knows its duration.
  void _onLottieLoaded(LottieComposition composition) {
    // Dismiss native splash now that Lottie's first frame is ready.
    FlutterNativeSplash.remove();
    _controller
      ..duration = composition.duration
      ..forward().whenComplete(() {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRouter.auth);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/splash_animation.json',
          controller: _controller,
          onLoaded: _onLottieLoaded,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}