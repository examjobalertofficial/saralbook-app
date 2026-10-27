import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../render/canvas_export.dart';
import '../tools/files/image_ops.dart';

/// Text height as a part of the picture width (at "Medium").
const double kNoteFontFraction = 0.07;

/// How the note under the picture looks.
class NoteStyle {
  final List<String> lines;
  final double scale; // 0.7 small, 1 medium, 1.4 large
  final int textColor; // 0xAARRGGBB
  final int stripColor;
  final bool bold;
  const NoteStyle({
    required this.lines,
    this.scale = 1,
    this.textColor = 0xFF000000,
    this.stripColor = 0xFFFFFFFF,
    this.bold = true,
  });
}

class NoteResult {
  final Uint8List bytes;
  final int width;
  final int height;
  final bool png;

  /// false when a size limit was asked for but could not be reached.
  final bool metTarget;
  const NoteResult(this.bytes, this.width, this.height, this.png, this.metTarget);
}

/// Height of the strip for a picture of [width] pixels (shared by the preview).
double noteFontSize(num width, double scale) => math.max(12.0, width * kNoteFontFraction * scale);

TextPainter _notePainter(NoteStyle style, double width) {
  final font = noteFontSize(width, style.scale);
  final pad = font * 0.6;
  return TextPainter(
    text: TextSpan(
      text: style.lines.join('\n'),
      style: TextStyle(
        color: Color(style.textColor),
        fontSize: font,
        fontWeight: style.bold ? FontWeight.w700 : FontWeight.w500,
        height: 1.25,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(minWidth: math.max(1.0, width - 2 * pad), maxWidth: math.max(1.0, width - 2 * pad));
}

/// Puts the note (white strip with text) under the picture.
/// [width] resizes the picture first. [maxBytes] makes a JPEG not bigger than that.
Future<NoteResult> buildPhotoWithNote({
  required Uint8List photo,
  required NoteStyle style,
  int? width,
  int? maxBytes,
  bool png = false,
}) async {
  final picture = await decodeUiImage(photo, targetWidth: width);
  final w = picture.width;
  final h = picture.height;
  final font = noteFontSize(w, style.scale);
  final pad = font * 0.6;
  final tp = _notePainter(style, w.toDouble());
  final stripH = (tp.height + 2 * pad).ceil();
  final totalH = h + stripH;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), totalH.toDouble()), Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawImage(picture, Offset.zero, Paint()..filterQuality = FilterQuality.high);
  canvas.drawRect(
    Rect.fromLTWH(0, h.toDouble(), w.toDouble(), stripH.toDouble()),
    Paint()..color = Color(style.stripColor),
  );
  tp.paint(canvas, Offset(pad, h + pad));
  final done = recorder.endRecording();
  final out = await done.toImage(w, totalH);
  final pixels = await readRgba(out);
  picture.dispose();
  out.dispose();
  done.dispose();

  return inBackground(() {
    final image = imageFromRgba(pixels.rgba, pixels.width, pixels.height);
    if (maxBytes != null) {
      final r = compressToTarget(image, maxBytes);
      return NoteResult(r.bytes, r.width, r.height, false, r.metTarget);
    }
    return png
        ? NoteResult(encodePngBytes(image), pixels.width, pixels.height, true, true)
        : NoteResult(encodeJpeg(image, 93), pixels.width, pixels.height, false, true);
  });
}
