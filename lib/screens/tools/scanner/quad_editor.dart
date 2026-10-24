import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// A picture with four draggable corners (the page outline).
/// [quad] is [x0,y0, x1,y1, x2,y2, x3,y3] as fractions of the picture.
class QuadEditor extends StatelessWidget {
  final Uint8List image;
  final double aspect; // width / height of the picture
  final List<double> quad;
  final ValueChanged<List<double>> onChanged;
  const QuadEditor({
    super.key,
    required this.image,
    required this.aspect,
    required this.quad,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, c) {
        var w = c.maxWidth;
        var h = w / aspect;
        if (h > c.maxHeight) {
          h = c.maxHeight;
          w = h * aspect;
        }
        const grab = 48.0;
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.memory(image, fit: BoxFit.fill, gaplessPlayback: true),
                ),
                Positioned.fill(
                  child: CustomPaint(painter: _QuadPainter(quad, color)),
                ),
                for (var i = 0; i < 4; i++)
                  Positioned(
                    left: quad[2 * i] * w - grab / 2,
                    top: quad[2 * i + 1] * h - grab / 2,
                    width: grab,
                    height: grab,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) {
                        final next = List<double>.of(quad);
                        next[2 * i] = math.min(1.0, math.max(0.0, next[2 * i] + d.delta.dx / w));
                        next[2 * i + 1] = math.min(1.0, math.max(0.0, next[2 * i + 1] + d.delta.dy / h));
                        onChanged(next);
                      },
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withAlpha(70),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuadPainter extends CustomPainter {
  final List<double> q;
  final Color color;
  _QuadPainter(this.q, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(q[0] * size.width, q[1] * size.height)
      ..lineTo(q[2] * size.width, q[3] * size.height)
      ..lineTo(q[4] * size.width, q[5] * size.height)
      ..lineTo(q[6] * size.width, q[7] * size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withAlpha(36));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_QuadPainter old) => old.q != q || old.color != color;
}
