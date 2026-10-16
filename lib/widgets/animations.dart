import 'package:flutter/material.dart';

/// Fades and slides its child up a little when it first appears.
/// [index] staggers a list (each item starts a bit later). Uses only built-in
/// Flutter animation, so it adds no size to the app.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, 8);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + i * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// A soft gradient banner used at the top of the main tabs.
class GradientBanner extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GradientBanner({
    super.key,
    required this.colors,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: colors.last.withAlpha(70), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}

/// Press feedback: the child shrinks slightly while it is pressed.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const PressScale({super.key, required this.child, this.onTap});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
