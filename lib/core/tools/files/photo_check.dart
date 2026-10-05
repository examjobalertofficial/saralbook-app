import 'image_ops.dart';

/// What a form asks for (leave a value null if the form does not say).
class PhotoSpec {
  final int? width;
  final int? height;
  final double? minKb;
  final double? maxKb;
  final ImageFormat? format; // null = any of JPG/PNG
  const PhotoSpec({this.width, this.height, this.minKb, this.maxKb, this.format});
}

class PhotoFacts {
  final int width;
  final int height;
  final int bytes;
  final ImageFormat format;
  const PhotoFacts(this.width, this.height, this.bytes, this.format);
  double get kb => bytes / 1024;
}

enum CheckKind { dimensions, minSize, maxSize, format }

class CheckItem {
  final CheckKind kind;
  final bool ok;

  /// Short machine-friendly detail, e.g. "200x230 px" or "48.2 KB".
  final String actual;
  final String required;
  const CheckItem(this.kind, this.ok, this.actual, this.required);
}

String _kb(double v) => v.toStringAsFixed(1);

String formatName(ImageFormat f) => switch (f) {
      ImageFormat.jpeg => 'JPG',
      ImageFormat.png => 'PNG',
      ImageFormat.webp => 'WEBP',
      ImageFormat.unknown => '?',
    };

List<CheckItem> checkPhoto(PhotoSpec spec, PhotoFacts facts) {
  final items = <CheckItem>[];
  if (spec.width != null || spec.height != null) {
    final okW = spec.width == null || spec.width == facts.width;
    final okH = spec.height == null || spec.height == facts.height;
    items.add(CheckItem(
      CheckKind.dimensions,
      okW && okH,
      '${facts.width}×${facts.height} px',
      '${spec.width ?? '—'}×${spec.height ?? '—'} px',
    ));
  }
  if (spec.minKb != null) {
    items.add(CheckItem(CheckKind.minSize, facts.kb >= spec.minKb!, '${_kb(facts.kb)} KB', '≥ ${_kb(spec.minKb!)} KB'));
  }
  if (spec.maxKb != null) {
    items.add(CheckItem(CheckKind.maxSize, facts.kb <= spec.maxKb!, '${_kb(facts.kb)} KB', '≤ ${_kb(spec.maxKb!)} KB'));
  }
  final wanted = spec.format;
  final okFormat = wanted == null
      ? (facts.format == ImageFormat.jpeg || facts.format == ImageFormat.png)
      : facts.format == wanted;
  items.add(CheckItem(
    CheckKind.format,
    okFormat,
    formatName(facts.format),
    wanted == null ? 'JPG / PNG' : formatName(wanted),
  ));
  return items;
}

bool allChecksPass(List<CheckItem> items) => items.every((e) => e.ok);
