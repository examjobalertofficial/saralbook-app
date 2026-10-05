import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../widgets/page_body.dart';

enum PomodoroPhase { focus, shortBreak, longBreak }

const Map<PomodoroPhase, Duration> pomodoroDurations = {
  PomodoroPhase.focus: Duration(minutes: 25),
  PomodoroPhase.shortBreak: Duration(minutes: 5),
  PomodoroPhase.longBreak: Duration(minutes: 15),
};

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  PomodoroPhase _phase = PomodoroPhase.focus;
  Duration _remaining = pomodoroDurations[PomodoroPhase.focus]!;
  DateTime? _endAt;
  Timer? _timer;
  bool _running = false;
  int _sessions = 0;

  Duration get _total => pomodoroDurations[_phase]!;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setPhase(PomodoroPhase p) {
    _timer?.cancel();
    setState(() {
      _phase = p;
      _remaining = pomodoroDurations[p]!;
      _running = false;
      _endAt = null;
    });
  }

  void _start() {
    // Based on the end time (not on counting ticks), so it stays accurate
    // even if the screen was off for a while.
    _endAt = DateTime.now().add(_remaining);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    setState(() => _running = true);
  }

  void _pause() {
    final end = _endAt;
    if (end != null) {
      final left = end.difference(DateTime.now());
      _remaining = left.isNegative ? Duration.zero : left;
    }
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _tick() {
    final end = _endAt;
    if (end == null) return;
    final left = end.difference(DateTime.now());
    if (left <= Duration.zero) {
      _finish();
    } else {
      setState(() => _remaining = left);
    }
  }

  void _finish() {
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    PomodoroPhase next;
    if (_phase == PomodoroPhase.focus) {
      _sessions += 1;
      next = _sessions % 4 == 0 ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak;
    } else {
      next = PomodoroPhase.focus;
    }
    _setPhase(next);
  }

  String _label(AppStrings s, PomodoroPhase p) => switch (p) {
        PomodoroPhase.focus => s.focus,
        PomodoroPhase.shortBreak => s.shortBreak,
        PomodoroPhase.longBreak => s.longBreak,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final progress = 1 - (_remaining.inMilliseconds / _total.inMilliseconds);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.pomodoroTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                for (final p in PomodoroPhase.values)
                  ChoiceChip(
                    label: Text(_label(s, p)),
                    selected: _phase == p,
                    onSelected: (_) => _setPhase(p),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        strokeWidth: 10,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    Text(
                      '$mm:$ss',
                      style: text.displayMedium?.copyWith(fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(onPressed: () => _setPhase(_phase), child: Text(s.reset)),
                FilledButton(
                  onPressed: _running ? _pause : _start,
                  child: Text(_running ? s.pause : s.start),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(child: Text('${s.sessionsDone}: $_sessions', style: text.bodyLarge)),
          ],
        ),
      ),
    );
  }
}
