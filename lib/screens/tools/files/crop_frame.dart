import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Lets the owner of a [CropFrame] read the chosen area afterwards.
class CropController {
  Rect? Function()? _region;

  /// The visible area in pixels of the original picture (null if not shown yet).
  Rect? get region => _region?.call();
}

/// A fixed-shape frame; the user moves and zooms the picture under it.
/// (Like passport-photo apps: simple on a phone, no tiny handles.)
class CropFrame extends StatefulWidget {
  final Uint8List bytes;
  final int imageWidth;
  final int imageHeight;

  /// width / height of the frame
  final double aspect;
  final CropController controller;
  final double maxHeight;

  const CropFrame({
    super.key,
    required this.bytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.aspect,
    required this.controller,
    this.maxHeight = 380,
  });

  @override
  State<CropFrame> createState() => _CropFrameState();
}

class _CropFrameState extends State<CropFrame> {
  final TransformationController _tc = TransformationController();
  Size _frame = Size.zero;
  Size _cover = Size.zero;
  String? _centeredFor;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _center() {
    final dx = (_cover.width - _frame.width) / 2;
    final dy = (_cover.height - _frame.height) / 2;
    _tc.value = Matrix4.translationValues(-dx, -dy, 0);
  }

  Rect? _region() {
    if (_cover.width <= 0) return null;
    final tl = _tc.toScene(Offset.zero);
    final br = _tc.toScene(Offset(_frame.width, _frame.height));
    final s = widget.imageWidth / _cover.width;
    return Rect.fromLTRB(tl.dx * s, tl.dy * s, br.dx * s, br.dy * s);
  }

  @override
  Widget build(BuildContext context) {
    widget.controller._region = _region;
    return LayoutBuilder(
      builder: (context, c) {
        var fw = c.maxWidth;
        var fh = fw / widget.aspect;
        if (fh > widget.maxHeight) {
          fh = widget.maxHeight;
          fw = fh * widget.aspect;
        }
        final scale = math.max(fw / widget.imageWidth, fh / widget.imageHeight);
        final cw = widget.imageWidth * scale;
        final ch = widget.imageHeight * scale;
        _frame = Size(fw, fh);
        _cover = Size(cw, ch);

        final signature =
            '${fw.toStringAsFixed(1)}x${fh.toStringAsFixed(1)}:${widget.bytes.length}';
        if (_centeredFor != signature) {
          _centeredFor = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _center();
          });
        }

        return Center(
          child: Container(
            color: Colors.black,
            width: fw,
            height: fh,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: InteractiveViewer(
                      transformationController: _tc,
                      constrained: false,
                      minScale: 1,
                      maxScale: 8,
                      boundaryMargin: EdgeInsets.zero,
                      child: SizedBox(
                        width: cw,
                        height: ch,
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
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
