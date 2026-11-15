import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/rating/rating_policy.dart';

/// Invisible. Counts app starts and, when the person has used the app enough,
/// shows Google's own rating box once the Home screen has been open a while.
class RatingTrigger extends StatefulWidget {
  const RatingTrigger({super.key});

  @override
  State<RatingTrigger> createState() => _RatingTriggerState();
}

class _RatingTriggerState extends State<RatingTrigger> {
  static bool _countedThisStart = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var state = RatingState.decode(prefs.getString(_key));
      final now = DateTime.now();
      if (!_countedThisStart) {
        _countedThisStart = true;
        state = state.opened(now);
        await prefs.setString(_key, state.encode());
      }
      if (!state.shouldAsk(now)) return;
      // Wait a little so the box never pops up the moment Home opens.
      _timer = Timer(const Duration(seconds: 25), () => unawaited(_ask(prefs)));
    } catch (_) {/* the rating box is optional: ignore any problem */}
  }

  static const String _key = 'rating.v1';

  Future<void> _ask(SharedPreferences prefs) async {
    try {
      if (!mounted) return;
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      final now = DateTime.now();
      final state = RatingState.decode(prefs.getString(_key));
      if (!state.shouldAsk(now)) return;
      await prefs.setString(_key, state.wasAsked(now).encode());
      await review.requestReview();
    } catch (_) {/* ignore */}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
