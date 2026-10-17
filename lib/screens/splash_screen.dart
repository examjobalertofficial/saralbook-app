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

/// Start-up screen: the logo pops in with a glow, "Welcome to SaralBook" fades
/// up, then a quote. Tap anywhere to skip. Pure Flutter animation (no extra files).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  late final LText _quote = splashQuotes[math.Random().nextInt(splashQuotes.length)];
  Timer? _timer;

  Animation<double> _in(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(from, to, curve: curve));

  late final Animation<double> _logo = _in(0.0, 0.40, Curves.easeOutBack);
  late final Animation<double> _welcome = _in(0.30, 0.58);
  late final Animation<double> _name = _in(0.42, 0.70);
  late final Animation<double> _quoteIn = _in(0.60, 0.90);

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3000), _go);
  }

  void _go() {
    if (!mounted) return;
    _timer?.cancel();
    context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Widget _fadeUp(Animation<double> a, Widget child, {double dy = 16}) => AnimatedBuilder(
        animation: a,
        builder: (context, child) => Opacity(
          opacity: a.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - a.value) * dy), child: child),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E5AA8), Color(0xFF7048E8), Color(0xFFD6336C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final pop = _logo.value.clamp(0.0, 1.2);
                    final pulse = 1 + 0.05 * math.sin(_c.value * math.pi * 4) * _c.value;
                    return Transform.scale(
                      scale: pop * pulse,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withAlpha(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withAlpha((90 * _logo.value.clamp(0.0, 1.0)).round()),
                              blurRadius: 40,
                              spreadRadius: 6,
                            ),
                          ],
                        ),
                        child: const BrandLogo(size: 104),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                _fadeUp(
                  _welcome,
                  Text(
                    tr(context, t('Welcome to', 'आपका स्वागत है')),
                    style: const TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 4),
                _fadeUp(
                  _name,
                  const Text(
                    'SaralBook',
                    style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
                  ),
                ),
                const Spacer(flex: 2),
                _fadeUp(
                  _quoteIn,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      children: [
                        const Icon(Icons.format_quote_rounded, color: Colors.white54, size: 30),
                        Text(
                          tr(context, _quote),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  dy: 10,
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(60, 0, 60, 36),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => LinearProgressIndicator(
                        value: _c.value,
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
