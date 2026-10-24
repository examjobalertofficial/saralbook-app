import 'dart:typed_data';

import 'scan_engine.dart';

/// One scanned page while the person is working on it.
class ScanPage {
  /// Sharp working copy (long side up to 2400 px). Used for the final file.
  final Uint8List src;

  /// Smaller copy (up to 1200 px) used on screen so editing stays quick.
  final Uint8List preview;
  final int width;
  final int height;

  /// Page corners, see [fullPageQuad].
  List<double> quad;
  int filter; // index into ScanFilter.values
  double brightness; // -100..100
  double contrast; // -100..100
  int rotation; // quarter turns clockwise

  /// Small finished picture for the page list.
  Uint8List? thumb;

  ScanPage({
    required this.src,
    required this.preview,
    required this.width,
    required this.height,
    required this.quad,
    this.filter = 1, // Magic Color
    this.brightness = 0,
    this.contrast = 0,
    this.rotation = 0,
    this.thumb,
  });

  factory ScanPage.fromImport(ScanImport i) => ScanPage(
        src: i.src,
        preview: i.preview,
        width: i.width,
        height: i.height,
        quad: List<double>.of(i.quad),
      );

  Future<Uint8List> renderThumb() => renderScanAsync(
        preview,
        quad,
        filter: filter,
        brightness: brightness,
        contrast: contrast,
        rotation: rotation,
        maxSide: 360,
        quality: 70,
      );

  /// The finished picture at full quality.
  Future<Uint8List> renderFinal({int quality = 88}) => renderScanAsync(
        src,
        quad,
        filter: filter,
        brightness: brightness,
        contrast: contrast,
        rotation: rotation,
        maxSide: 2200,
        quality: quality,
      );
}
