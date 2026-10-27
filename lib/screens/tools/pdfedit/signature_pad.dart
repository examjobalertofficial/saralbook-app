import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/render/canvas_export.dart';
import '../files/file_ui.dart' show tx;
import 'pdf_editor_text.dart';

class SignatureResult {
  final Uint8List png;
  final double aspect;
  const SignatureResult(this.png, this.aspect);
}

/// A small pad to draw a signature with the finger. Returns a transparent PNG.
class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({super.key});

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  bool _working = false;

  static const int _ink = 0xFF1A237E;

  Future<void> _use() async {
    if (_strokes.isEmpty || _working) return;
    setState(() => _working = true);
    try {
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final s in _strokes) {
        for (final p in s) {
          minX = math.min(minX, p.dx);
          minY = math.min(minY, p.dy);
          maxX = math.max(maxX, p.dx);
          maxY = math.max(maxY, p.dy);
        }
      }
      const margin = 8.0;
      final bw = math.max(maxX - minX, 1.0) + 2 * margin;
      final bh = math.max(maxY - minY, 1.0) + 2 * margin;
      final scale = 800 / math.max(bw, bh * 2);
      final w = math.max(1, (bw * scale).round());
      final h = math.max(1, (bh * scale).round());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.translate(margin * scale - minX * scale, margin * scale - minY * scale);
      _paintStrokes(canvas, _strokes, scale, 3.0 * scale);
      final picture = recorder.endRecording();
      final image = await picture.toImage(w, h);
      final png = await pngFromUiImage(image);
      image.dispose();
      picture.dispose();
      if (mounted) Navigator.of(context).pop(SignatureResult(png, w / h));
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  static void _paintStrokes(Canvas canvas, List<List<Offset>> strokes, double scale, double width) {
    final paint = Paint()
      ..color = const Color(_ink)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      if (s.length == 1) {
        canvas.drawCircle(s.first * scale, width / 2, Paint()..color = const Color(_ink));
        continue;
      }
      final path = Path()..moveTo(s.first.dx * scale, s.first.dy * scale);
      for (final p in s.skip(1)) {
        path.lineTo(p.dx * scale, p.dy * scale);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tx(context, EdTx.drawSignature), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                onPanUpdate: (d) {
                  if (_strokes.isEmpty) return;
                  setState(() => _strokes.last.add(d.localPosition));
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PadPainter(_strokes),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                  child: Text(tx(context, EdTx.clear)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tx(context, EdTx.cancel)),
                ),
                FilledButton(
                  onPressed: (_strokes.isEmpty || _working) ? null : _use,
                  child: Text(tx(context, EdTx.use)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  const _PadPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    _SignaturePadDialogState._paintStrokes(canvas, strokes, 1, 3);
  }

  @override
  bool shouldRepaint(covariant _PadPainter old) => true;
}
