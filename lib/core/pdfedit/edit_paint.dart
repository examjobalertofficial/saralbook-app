import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../render/canvas_export.dart';
import '../tools/files/image_ops.dart' show inBackground;
import 'edit_model.dart';

/// Lays out the text of a [TextItem] for a page of [size].
TextPainter textPainterFor(TextItem t, Size size) => TextPainter(
      text: TextSpan(
        text: t.text,
        style: TextStyle(
          color: Color(t.color),
          fontSize: math.max(4.0, t.size * size.width),
          fontWeight: t.bold ? FontWeight.w700 : FontWeight.w400,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(10.0, (1 - t.x) * size.width));

/// Where an item is on a page of [size] (null for pen strokes, which cannot be selected).
Rect? itemBounds(EditItem item, Size size) {
  if (item is TextItem) {
    final tp = textPainterFor(item, size);
    return Rect.fromLTWH(item.x * size.width, item.y * size.height, tp.width, tp.height);
  }
  if (item is PictureItem) {
    final w = item.w * size.width;
    return Rect.fromLTWH(item.x * size.width, item.y * size.height, w, w / item.aspect);
  }
  if (item is CoverItem) {
    return Rect.fromLTWH(item.x * size.width, item.y * size.height, item.w * size.width, item.h * size.height);
  }
  return null;
}

/// The top-most selectable item at [p] (page coordinates), or null.
EditItem? hitTestItems(List<EditItem> items, Offset p, Size size) {
  for (var i = items.length - 1; i >= 0; i--) {
    final b = itemBounds(items[i], size);
    if (b != null && b.inflate(size.width * 0.012).contains(p)) return items[i];
  }
  return null;
}

/// Draws the page picture and everything added on it. Used on screen and for the saved file.
void paintPage(
  Canvas canvas,
  Size size, {
  required ui.Image? base,
  required List<EditItem> items,
  required Map<String, ui.Image> pictures,
  String? selectedId,
}) {
  final full = Rect.fromLTWH(0, 0, size.width, size.height);
  canvas.drawRect(full, Paint()..color = const Color(0xFFFFFFFF));
  if (base != null) {
    canvas.drawImageRect(
      base,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
      full,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
  for (final item in items) {
    if (item is CoverItem) {
      canvas.drawRect(
        Rect.fromLTWH(item.x * size.width, item.y * size.height, item.w * size.width, item.h * size.height),
        Paint()..color = Color(item.color),
      );
    } else if (item is InkItem) {
      _paintInk(canvas, size, item);
    } else if (item is TextItem) {
      textPainterFor(item, size).paint(canvas, Offset(item.x * size.width, item.y * size.height));
    } else if (item is PictureItem) {
      final image = pictures[item.id];
      if (image != null) {
        final w = item.w * size.width;
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(item.x * size.width, item.y * size.height, w, w / item.aspect),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
    }
  }
  if (selectedId != null) {
    for (final item in items) {
      if (item.id != selectedId) continue;
      final b = itemBounds(item, size);
      if (b == null) continue;
      final r = b.inflate(size.width * 0.006);
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, size.width * 0.003)
          ..color = const Color(0xFF1E88E5),
      );
      final dot = Paint()..color = const Color(0xFF1E88E5);
      final rad = math.max(3.0, size.width * 0.007);
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        canvas.drawCircle(c, rad, dot);
      }
    }
  }
}

void _paintInk(Canvas canvas, Size size, InkItem item) {
  final pts = item.points;
  if (pts.length < 2) return;
  final w = math.max(1.0, item.width * size.width);
  final paint = Paint()
    ..color = Color(item.color)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w;
  // a highlighter darkens the page but keeps the text readable
  if (item.highlight) paint.blendMode = BlendMode.multiply;
  if (pts.length < 4) {
    canvas.drawCircle(
      Offset(pts[0] * size.width, pts[1] * size.height),
      w / 2,
      Paint()
        ..color = Color(item.color)
        ..blendMode = item.highlight ? BlendMode.multiply : BlendMode.srcOver,
    );
    return;
  }
  final path = Path()..moveTo(pts[0] * size.width, pts[1] * size.height);
  for (var i = 2; i + 1 < pts.length; i += 2) {
    path.lineTo(pts[i] * size.width, pts[i + 1] * size.height);
  }
  canvas.drawPath(path, paint);
}

void _paintWatermark(Canvas canvas, Size size, String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0x30000000),
        fontSize: size.width * 0.11,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size.width * 1.3);
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.rotate(-0.6);
  tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  canvas.restore();
}

void _paintNumber(Canvas canvas, Size size, String text, PageNumberPos pos) {
  if (pos == PageNumberPos.none) return;
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: const Color(0xFF424242), fontSize: size.width * 0.028, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final m = size.width * 0.05;
  final Offset at = switch (pos) {
    PageNumberPos.bottomCenter => Offset((size.width - tp.width) / 2, size.height - m - tp.height),
    PageNumberPos.bottomRight => Offset(size.width - m - tp.width, size.height - m - tp.height),
    PageNumberPos.bottomLeft => Offset(m, size.height - m - tp.height),
    PageNumberPos.topRight => Offset(size.width - m - tp.width, m),
    PageNumberPos.none => Offset.zero,
  };
  tp.paint(canvas, at);
}

/// Paints the page on screen (the same code that makes the saved file).
class EditPagePainter extends CustomPainter {
  final ui.Image? base;
  final List<EditItem> items;
  final Map<String, ui.Image> pictures;
  final String? selectedId;
  final int revision;
  const EditPagePainter({
    required this.base,
    required this.items,
    required this.pictures,
    required this.selectedId,
    required this.revision,
  });

  @override
  void paint(Canvas canvas, Size size) =>
      paintPage(canvas, size, base: base, items: items, pictures: pictures, selectedId: selectedId);

  @override
  bool shouldRepaint(covariant EditPagePainter old) => true;
}

/// Makes the final picture of one page (page + additions + number + watermark) as JPEG.
Future<Uint8List> renderEditedPage(
  EditPage page, {
  required int quality,
  String? numberText,
  PageNumberPos numberPos = PageNumberPos.none,
  String watermark = '',
}) async {
  final base = await decodeUiImage(page.base);
  final pictures = <String, ui.Image>{};
  try {
    for (final it in page.items) {
      if (it is PictureItem) pictures[it.id] = await decodeUiImage(it.bytes);
    }
    final size = Size(base.width.toDouble(), base.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintPage(canvas, size, base: base, items: page.items, pictures: pictures);
    if (watermark.trim().isNotEmpty) _paintWatermark(canvas, size, watermark.trim());
    if (numberText != null) _paintNumber(canvas, size, numberText, numberPos);
    final picture = recorder.endRecording();
    final out = await picture.toImage(base.width, base.height);
    final px = await readRgba(out);
    out.dispose();
    picture.dispose();
    return await inBackground(() => jpegFromRgba(px.rgba, px.width, px.height, quality));
  } finally {
    base.dispose();
    for (final p in pictures.values) {
      p.dispose();
    }
  }
}

/// Turns the page picture a quarter turn clockwise.
Future<EditPage> rotatePageClockwise(EditPage page) async {
  final base = await decodeUiImage(page.base);
  try {
    final w = base.width;
    final h = base.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(h.toDouble(), 0);
    canvas.rotate(math.pi / 2);
    canvas.drawImage(base, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    final picture = recorder.endRecording();
    final out = await picture.toImage(h, w);
    final px = await readRgba(out);
    out.dispose();
    picture.dispose();
    final jpeg = await inBackground(() => jpegFromRgba(px.rgba, px.width, px.height, 92));
    return EditPage(base: jpeg, width: h, height: w, key: page.key);
  } finally {
    base.dispose();
  }
}
