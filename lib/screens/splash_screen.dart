import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/ltext.dart';
import '../core/router/app_router.dart';
import '../widgets/brand_logo.dart';
import '../widgets/tr.dart';

/// Short, encouraging lines for students. One is picked at random each start.
final List<LText> splashQuotes = [
  t('Learn today, lead tomorrow.', 'आज सीखिए, कल नेतृत्व कीजिए।'),
  t('Dream big. Study smart. Achieve more.', 'बड़े सपने देखिए, स्मार्ट पढ़िए, ज़्यादा पाइए।'),
  t('Every expert was once a beginner.', 'हर विशेषज्ञ कभी शुरुआत करने वाला था।'),
  t('Small steps every day build big success.', 'हर दिन के छोटे कदम बड़ी सफलता बनाते हैं।'),
  t('Your hard work will write your success story.', 'आपकी मेहनत ही आपकी सफलता की कहानी लिखेगी।'),
  t('Believe in yourself. Your government job is waiting.', 'खुद पर भरोसा रखिए, आपकी सरकारी नौकरी इंतज़ार में है।'),
];

/// Start-up screen: logo, "Welcome to SaralBook" and a quote, each fading in.
/// Deliberately light (no blur or glow effects) so it starts instantly even on
/// slow phones. Tap anywhere to skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _logo;
  late final Animation<double> _welcome;
  late final Animation<double> _quoteIn;
  late final LText _quote;
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _quote = splashQuotes[math.Random().nextInt(splashQuotes.length)];
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    Animation<double> step(double a, double b) =>
        CurvedAnimation(parent: _c, curve: Interval(a, b, curve: Curves.easeOut));
    _logo = step(0.0, 0.45);
    _welcome = step(0.30, 0.70);
    _quoteIn = step(0.55, 1.0);
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 2600), _go);
  }

  void _go() {
    if (!mounted || _left) return;
    _left = true;
    _timer?.cancel();
    context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E5AA8), Color(0xFF7048E8), Color(0xFFD6336C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SizedBox.expand(
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logo,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.0).animate(_logo),
                      child: const BrandLogo(size: 110),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _welcome,
                    child: Column(
                      children: [
                        Text(
                          tr(context, t('Welcome to', 'आपका स्वागत है')),
                          style: const TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SaralBook',
                          style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  FadeTransition(
                    opacity: _quoteIn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        '“${tr(context, _quote)}”',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
