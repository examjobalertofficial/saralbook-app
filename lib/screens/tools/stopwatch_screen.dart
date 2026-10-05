import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../widgets/page_body.dart';

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final cs = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s.$cs' : '$m:$s.$cs';
}

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _sw = Stopwatch();
  final List<Duration> _laps = [];
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _sw.start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) => setState(() {}));
    setState(() {});
  }

  void _pause() {
    _sw.stop();
    _ticker?.cancel();
    setState(() {});
  }

  void _reset() {
    _sw.reset();
    _laps.clear();
    setState(() {});
  }

  void _lap() => setState(() => _laps.insert(0, _sw.elapsed));

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    final running = _sw.isRunning;
    final started = _sw.elapsed > Duration.zero;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.stopwatchTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Semantics(
              label: formatDuration(_sw.elapsed),
              child: ExcludeSemantics(
                child: FittedBox(
                  child: Text(
                    formatDuration(_sw.elapsed),
                    style: text.displayLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: started ? _reset : null,
                  child: Text(s.reset),
                ),
                OutlinedButton(
                  onPressed: running ? _lap : null,
                  child: Text(s.lap),
                ),
                FilledButton(
                  onPressed: running ? _pause : _start,
                  child: Text(running ? s.pause : (started ? s.resume : s.start)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _laps.length,
                itemBuilder: (context, i) {
                  final number = _laps.length - i;
                  final previous = i + 1 < _laps.length ? _laps[i + 1] : Duration.zero;
                  return ListTile(
                    dense: true,
                    leading: Text('${s.lap} $number'),
                    title: Text(
                      formatDuration(_laps[i]),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    trailing: Text(
                      '+${formatDuration(_laps[i] - previous)}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
