import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../widgets/brand_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      context.go(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Fixed colours: this screen looks the same in light and dark mode.
  static const _bg = Color(0xFFEAF2FF);
  static const _navy = Color(0xFF2A356B);
  static const _blue = Color(0xFF1E5AA8);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 104),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to SaralBook',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _navy, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'सरलबुक में आपका स्वागत है',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _blue, fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 3, color: _blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
