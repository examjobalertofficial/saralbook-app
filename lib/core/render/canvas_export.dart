import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Pixels (RGBA) of a picture drawn with a canvas.
Future<({Uint8List rgba, int width, int height})> readRgba(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw StateError('Could not read the picture');
  final bytes = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  return (rgba: bytes, width: image.width, height: image.height);
}

/// RGBA pixels -> an image object (call this inside a background isolate).
img.Image imageFromRgba(Uint8List rgba, int width, int height) => img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

/// RGBA pixels -> JPEG (the canvas is always filled, so no transparency is lost).
Uint8List jpegFromRgba(Uint8List rgba, int width, int height, int quality) => img.encodeJpg(
      imageFromRgba(rgba, width, height),
      quality: quality.clamp(1, 100),
      chroma: img.JpegChroma.yuv420,
    );

/// A canvas picture -> PNG bytes (keeps transparency).
Future<Uint8List> pngFromUiImage(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  if (data == null) throw StateError('Could not encode the picture');
  return Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
}

/// Decodes picture bytes (optionally scaled to [targetWidth]).
Future<ui.Image> decodeUiImage(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}
