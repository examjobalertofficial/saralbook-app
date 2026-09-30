import 'package:flutter/material.dart';

/// Shows assets/branding/logo.png. Replace that file to use your real logo.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/branding/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          color: primary,
          alignment: Alignment.center,
          child: Text(
            'S',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.55,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
