import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../tools/files/image_ops.dart' show decodeOriented, encodeJpeg, inBackground, resizeKeepRatio;

/// Document scanner maths: find the page in a photo, flatten it (perspective
/// fix), clean it with a filter. Pure Dart, no network, no other services.
/// Everything heavy is wrapped in `*Async` functions that run on a background
/// isolate so the app never freezes.

/// The looks a scan can have. Order matters (it is stored as a number).
enum ScanFilter { original, magic, blackWhite, grayscale, lighten, sharp }

/// Four corners of the page inside the picture, as fractions 0..1:
/// [x0,y0, x1,y1, x2,y2, x3,y3] = top-left, top-right, bottom-right, bottom-left.
List<double> fullPageQuad() => <double>[0.03, 0.03, 0.97, 0.03, 0.97, 0.97, 0.03, 0.97];

/// A picture as plain red-green-blue bytes.
class _Rgb {
  final int w;
  final int h;
  final Uint8List d; // w * h * 3
  _Rgb(this.w, this.h, this.d);
}

_Rgb _toRgb(img.Image image) {
  var im = image;
  if (im.numChannels != 3 || im.format != img.Format.uint8) {
    im = im.convert(format: img.Format.uint8, numChannels: 3);
  }
  final bytes = im.getBytes(order: img.ChannelOrder.rgb);
  return _Rgb(im.width, im.height, Uint8List.fromList(bytes));
}

Uint8List _encode(_Rgb im, int quality) {
  final image = img.Image.fromBytes(
    width: im.w,
    height: im.h,
    bytes: im.d.buffer,
    bytesOffset: im.d.offsetInBytes,
    numChannels: 3,
  );
  return encodeJpeg(image, quality);
}

double _cd(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

int _clamp255(num v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

// ---------------------------------------------------------------------------
// 1. Find the page
// ---------------------------------------------------------------------------

/// Looks for the sheet of paper in [jpeg] and returns its four corners
/// (see [fullPageQuad]). If no clear page is found, returns the whole picture.
List<double> detectDocumentQuad(Uint8List jpeg) {
  try {
    var image = decodeOriented(jpeg);
    if (image == null) return fullPageQuad();
    final longest = math.max(image.width, image.height);
    if (longest > 480) {
      image = resizeKeepRatio(
        image,
        width: image.width >= image.height ? 480 : null,
        height: image.height > image.width ? 480 : null,
      );
    }
    return _findQuad(_toRgb(image)) ?? fullPageQuad();
  } catch (_) {
    return fullPageQuad();
  }
}

Uint8List _gray(_Rgb im) {
  final n = im.w * im.h;
  final g = Uint8List(n);
  final d = im.d;
  for (var i = 0, p = 0; i < n; i++, p += 3) {
    g[i] = (d[p] * 77 + d[p + 1] * 151 + d[p + 2] * 28) >> 8;
  }
  return g;
}

/// Box blur with the given radius (separable, edges repeat).
Uint8List _boxBlur(Uint8List src, int w, int h, int r) {
  if (r <= 0) return src;
  final tmp = Uint8List(src.length);
  final out = Uint8List(src.length);
  final span = 2 * r + 1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var sum = 0;
    for (var k = -r; k <= r; k++) {
      sum += src[row + k.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = sum ~/ span;
      sum += src[row + (x + r + 1).clamp(0, w - 1)] - src[row + (x - r).clamp(0, w - 1)];
    }
  }
  for (var x = 0; x < w; x++) {
    var sum = 0;
    for (var k = -r; k <= r; k++) {
      sum += tmp[k.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = sum ~/ span;
      sum += tmp[(y + r + 1).clamp(0, h - 1) * w + x] - tmp[(y - r).clamp(0, h - 1) * w + x];
    }
  }
  return out;
}

int _otsu(Uint8List g) {
  final hist = List<int>.filled(256, 0);
  for (final v in g) {
    hist[v]++;
  }
  final total = g.length;
  var sumAll = 0;
  for (var i = 0; i < 256; i++) {
    sumAll += i * hist[i];
  }
  var sumB = 0;
  var wB = 0;
  var best = 0.0;
  var threshold = 128;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB;
    final mF = (sumAll - sumB) / wF;
    final between = wB.toDouble() * wF * (mB - mF) * (mB - mF);
    if (between > best) {
      best = between;
      threshold = t;
    }
  }
  return threshold;
}

class _Blob {
  int area = 0;
  int minX = 1 << 30, minY = 1 << 30, maxX = -1, maxY = -1;
  // extreme pixels: top-left, top-right, bottom-right, bottom-left
  int tlX = 0, tlY = 0, trX = 0, trY = 0, brX = 0, brY = 0, blX = 0, blY = 0;
  int tlV = 1 << 30, trV = -(1 << 30), brV = -(1 << 30), blV = 1 << 30;
  int borders = 0; // how many picture sides it touches
}

/// The biggest connected group of pixels where [mask] is 1.
_Blob? _biggestBlob(Uint8List mask, int w, int h) {
  final seen = Uint8List(mask.length);
  final stack = Int32List(mask.length);
  _Blob? best;
  for (var start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || seen[start] == 1) continue;
    final blob = _Blob();
    var top = 0;
    stack[top++] = start;
    seen[start] = 1;
    var touchTop = false, touchBottom = false, touchLeft = false, touchRight = false;
    while (top > 0) {
      final p = stack[--top];
      final x = p % w;
      final y = p ~/ w;
      blob.area++;
      if (x < blob.minX) blob.minX = x;
      if (x > blob.maxX) blob.maxX = x;
      if (y < blob.minY) blob.minY = y;
      if (y > blob.maxY) blob.maxY = y;
      final sum = x + y;
      final diff = x - y;
      if (sum < blob.tlV) {
        blob.tlV = sum;
        blob.tlX = x;
        blob.tlY = y;
      }
      if (sum > blob.brV) {
        blob.brV = sum;
        blob.brX = x;
        blob.brY = y;
      }
      if (diff > blob.trV) {
        blob.trV = diff;
        blob.trX = x;
        blob.trY = y;
      }
      if (diff < blob.blV) {
        blob.blV = diff;
        blob.blX = x;
        blob.blY = y;
      }
      if (y == 0) touchTop = true;
      if (y == h - 1) touchBottom = true;
      if (x == 0) touchLeft = true;
      if (x == w - 1) touchRight = true;
      if (x > 0) {
        final q = p - 1;
        if (mask[q] == 1 && seen[q] == 0) {
          seen[q] = 1;
          stack[top++] = q;
        }
      }
      if (x < w - 1) {
        final q = p + 1;
        if (mask[q] == 1 && seen[q] == 0) {
          seen[q] = 1;
          stack[top++] = q;
        }
      }
      if (y > 0) {
        final q = p - w;
        if (mask[q] == 1 && seen[q] == 0) {
          seen[q] = 1;
          stack[top++] = q;
        }
      }
      if (y < h - 1) {
        final q = p + w;
        if (mask[q] == 1 && seen[q] == 0) {
          seen[q] = 1;
          stack[top++] = q;
        }
      }
    }
    blob.borders = (touchTop ? 1 : 0) + (touchBottom ? 1 : 0) + (touchLeft ? 1 : 0) + (touchRight ? 1 : 0);
    if (best == null || blob.area > best.area) best = blob;
  }
  return best;
}

double _polyArea(List<double> q) {
  var s = 0.0;
  for (var i = 0; i < 4; i++) {
    final j = (i + 1) % 4;
    s += q[2 * i] * q[2 * j + 1] - q[2 * j] * q[2 * i + 1];
  }
  return s.abs() / 2;
}

List<double>? _findQuad(_Rgb im) {
  final w = im.w, h = im.h;
  if (w < 16 || h < 16) return null;
  final g = _boxBlur(_gray(im), w, h, 2);
  final t = _otsu(g);
  final total = w * h;
  List<double>? best;
  var bestScore = 0.0;
  for (final bright in const [true, false]) {
    final mask = Uint8List(total);
    for (var i = 0; i < total; i++) {
      mask[i] = (bright ? g[i] > t : g[i] <= t) ? 1 : 0;
    }
    final blob = _biggestBlob(mask, w, h);
    if (blob == null) continue;
    final share = blob.area / total;
    final box = (blob.maxX - blob.minX + 1) * (blob.maxY - blob.minY + 1);
    final fill = blob.area / box;
    // too small, too big, ragged, or a frame around the picture = not a page
    if (share < 0.12 || share > 0.97 || fill < 0.55 || blob.borders >= 3) continue;
    final quad = <double>[
      (blob.tlX + 0.5) / w, (blob.tlY + 0.5) / h,
      (blob.trX + 0.5) / w, (blob.trY + 0.5) / h,
      (blob.brX + 0.5) / w, (blob.brY + 0.5) / h,
      (blob.blX + 0.5) / w, (blob.blY + 0.5) / h,
    ];
    if (_polyArea(quad) < 0.10) continue;
    final score = share * fill;
    if (score > bestScore) {
      bestScore = score;
      best = quad;
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// 2. Flatten the page (perspective fix)
// ---------------------------------------------------------------------------

double _dist(double ax, double ay, double bx, double by) =>
    math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));

_Rgb _warp(_Rgb src, List<double> q, int maxSide) {
  final x0 = q[0] * src.w, y0 = q[1] * src.h;
  final x1 = q[2] * src.w, y1 = q[3] * src.h;
  final x2 = q[4] * src.w, y2 = q[5] * src.h;
  final x3 = q[6] * src.w, y3 = q[7] * src.h;

  var outW = math.max(_dist(x0, y0, x1, y1), _dist(x3, y3, x2, y2));
  var outH = math.max(_dist(x0, y0, x3, y3), _dist(x1, y1, x2, y2));
  if (outW < 8 || outH < 8) {
    outW = math.max(outW, 8);
    outH = math.max(outH, 8);
  }
  final longest = math.max(outW, outH);
  if (longest > maxSide) {
    final k = maxSide / longest;
    outW *= k;
    outH *= k;
  }
  final ow = math.max(1, outW.round());
  final oh = math.max(1, outH.round());

  // Unit square -> quad (projective mapping).
  final sx = x0 - x1 + x2 - x3;
  final sy = y0 - y1 + y2 - y3;
  double a, b, c, d, e, f, g, h;
  c = x0;
  f = y0;
  if (sx.abs() < 1e-9 && sy.abs() < 1e-9) {
    a = x1 - x0;
    b = x3 - x0;
    d = y1 - y0;
    e = y3 - y0;
    g = 0;
    h = 0;
  } else {
    final dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2;
    final den = dx1 * dy2 - dx2 * dy1;
    if (den.abs() < 1e-9) {
      a = x1 - x0;
      b = x3 - x0;
      d = y1 - y0;
      e = y3 - y0;
      g = 0;
      h = 0;
    } else {
      g = (sx * dy2 - dy1 * sy) / den;
      h = (dx1 * sy - sx * dx2) / den;
      a = x1 - x0 + g * x1;
      b = x3 - x0 + h * x3;
      d = y1 - y0 + g * y1;
      e = y3 - y0 + h * y3;
    }
  }

  final out = Uint8List(ow * oh * 3);
  final sd = src.d;
  final sw = src.w, sh = src.h;
  var o = 0;
  for (var j = 0; j < oh; j++) {
    final t = (j + 0.5) / oh;
    for (var i = 0; i < ow; i++) {
      final s = (i + 0.5) / ow;
      final den = g * s + h * t + 1;
      final fx = (a * s + b * t + c) / den - 0.5;
      final fy = (d * s + e * t + f) / den - 0.5;
      var xi = fx.floor();
      var yi = fy.floor();
      final tx = fx - xi;
      final ty = fy - yi;
      final xa = xi < 0 ? 0 : (xi > sw - 1 ? sw - 1 : xi);
      final xb = xi + 1 < 0 ? 0 : (xi + 1 > sw - 1 ? sw - 1 : xi + 1);
      final ya = yi < 0 ? 0 : (yi > sh - 1 ? sh - 1 : yi);
      final yb = yi + 1 < 0 ? 0 : (yi + 1 > sh - 1 ? sh - 1 : yi + 1);
      final p00 = (ya * sw + xa) * 3;
      final p10 = (ya * sw + xb) * 3;
      final p01 = (yb * sw + xa) * 3;
      final p11 = (yb * sw + xb) * 3;
      final w00 = (1 - tx) * (1 - ty);
      final w10 = tx * (1 - ty);
      final w01 = (1 - tx) * ty;
      final w11 = tx * ty;
      for (var k = 0; k < 3; k++) {
        out[o++] = (sd[p00 + k] * w00 + sd[p10 + k] * w10 + sd[p01 + k] * w01 + sd[p11 + k] * w11 + 0.5).toInt();
      }
    }
  }
  return _Rgb(ow, oh, out);
}

_Rgb _rotate(_Rgb im, int turns) {
  final n = ((turns % 4) + 4) % 4;
  if (n == 0) return im;
  final w = im.w, h = im.h;
  if (n == 2) {
    final out = Uint8List(im.d.length);
    final total = w * h;
    for (var i = 0; i < total; i++) {
      final s = i * 3;
      final t = (total - 1 - i) * 3;
      out[t] = im.d[s];
      out[t + 1] = im.d[s + 1];
      out[t + 2] = im.d[s + 2];
    }
    return _Rgb(w, h, out);
  }
  final out = Uint8List(im.d.length);
  // new picture is h wide and w tall
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = (y * w + x) * 3;
      final int nx, ny;
      if (n == 1) {
        // 90 degrees clockwise
        nx = h - 1 - y;
        ny = x;
      } else {
        // 90 degrees counter-clockwise
        nx = y;
        ny = w - 1 - x;
      }
      final t = (ny * h + nx) * 3;
      out[t] = im.d[s];
      out[t + 1] = im.d[s + 1];
      out[t + 2] = im.d[s + 2];
    }
  }
  return _Rgb(h, w, out);
}

// ---------------------------------------------------------------------------
// 3. Filters
// ---------------------------------------------------------------------------

/// Evens out shadows and uneven light: the paper becomes (nearly) white while
/// ink and colours keep their strength.
_Rgb _flatten(_Rgb im) {
  final w = im.w, h = im.h;
  final d = im.d;
  final bs = math.max(6, (math.max(w, h) / 48).round());
  final gw = (w + bs - 1) ~/ bs;
  final gh = (h + bs - 1) ~/ bs;
  var grid = Float64List(gw * gh);

  // brightness of the paper in every block (a high percentile, so ink and
  // small marks are ignored)
  final hist = List<int>.filled(64, 0);
  for (var by = 0; by < gh; by++) {
    for (var bx = 0; bx < gw; bx++) {
      for (var i = 0; i < 64; i++) {
        hist[i] = 0;
      }
      var count = 0;
      final xEnd = math.min(w, (bx + 1) * bs);
      final yEnd = math.min(h, (by + 1) * bs);
      for (var y = by * bs; y < yEnd; y++) {
        var p = (y * w + bx * bs) * 3;
        for (var x = bx * bs; x < xEnd; x++, p += 3) {
          final l = (d[p] * 77 + d[p + 1] * 151 + d[p + 2] * 28) >> 8;
          hist[l >> 2]++;
          count++;
        }
      }
      var need = (count * 0.12).round();
      var bin = 63;
      while (bin > 0 && need > 0) {
        need -= hist[bin];
        if (need > 0) bin--;
      }
      grid[by * gw + bx] = (bin * 4 + 2).toDouble();
    }
  }
  // smooth twice
  for (var pass = 0; pass < 2; pass++) {
    final next = Float64List(gw * gh);
    for (var y = 0; y < gh; y++) {
      for (var x = 0; x < gw; x++) {
        var s = 0.0;
        var n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final yy = y + dy, xx = x + dx;
            if (yy < 0 || yy >= gh || xx < 0 || xx >= gw) continue;
            s += grid[yy * gw + xx];
            n++;
          }
        }
        next[y * gw + x] = s / n;
      }
    }
    grid = next;
  }

  // per-column interpolation positions
  final gx0 = Int32List(w);
  final gx1 = Int32List(w);
  final gxf = Float64List(w);
  for (var x = 0; x < w; x++) {
    final p = (x + 0.5) / bs - 0.5;
    final i0 = p.floor();
    gx0[x] = i0.clamp(0, gw - 1);
    gx1[x] = (i0 + 1).clamp(0, gw - 1);
    gxf[x] = _cd(p - i0, 0.0, 1.0);
  }

  final out = Uint8List(d.length);
  for (var y = 0; y < h; y++) {
    final p = (y + 0.5) / bs - 0.5;
    final j0 = p.floor();
    final r0 = j0.clamp(0, gh - 1) * gw;
    final r1 = (j0 + 1).clamp(0, gh - 1) * gw;
    final fy = _cd(p - j0, 0.0, 1.0);
    var o = y * w * 3;
    for (var x = 0; x < w; x++) {
      final fx = gxf[x];
      final top = grid[r0 + gx0[x]] * (1 - fx) + grid[r0 + gx1[x]] * fx;
      final bottom = grid[r1 + gx0[x]] * (1 - fx) + grid[r1 + gx1[x]] * fx;
      final bg = top * (1 - fy) + bottom * fy;
      final gain = 250.0 / (bg < 60 ? 60 : bg);
      out[o] = _clamp255(d[o] * gain);
      out[o + 1] = _clamp255(d[o + 1] * gain);
      out[o + 2] = _clamp255(d[o + 2] * gain);
      o += 3;
    }
  }
  return _Rgb(w, h, out);
}

Uint8List _lut(double Function(int v) f) {
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = _clamp255(f(v));
  }
  return lut;
}

_Rgb _applyLut(_Rgb im, Uint8List lut) {
  final out = Uint8List(im.d.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = lut[im.d[i]];
  }
  return _Rgb(im.w, im.h, out);
}

_Rgb _toGrayRgb(_Rgb im) {
  final n = im.w * im.h;
  final out = Uint8List(n * 3);
  final d = im.d;
  for (var i = 0, p = 0; i < n; i++, p += 3) {
    final y = (d[p] * 77 + d[p + 1] * 151 + d[p + 2] * 28) >> 8;
    out[p] = y;
    out[p + 1] = y;
    out[p + 2] = y;
  }
  return _Rgb(im.w, im.h, out);
}

double _smoothstep(double e0, double e1, double x) {
  final t = _cd((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Light sharpening (3x3).
_Rgb _sharpen(_Rgb im, {double amount = 0.7}) {
  final w = im.w, h = im.h;
  if (w < 3 || h < 3) return im;
  final d = im.d;
  final out = Uint8List.fromList(d);
  final center = 1 + 4 * amount;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final p = (y * w + x) * 3;
      for (var k = 0; k < 3; k++) {
        final v = d[p + k] * center -
            amount * (d[p - 3 + k] + d[p + 3 + k] + d[p - w * 3 + k] + d[p + w * 3 + k]);
        out[p + k] = _clamp255(v);
      }
    }
  }
  return _Rgb(w, h, out);
}

_Rgb _applyFilter(_Rgb im, ScanFilter filter) {
  switch (filter) {
    case ScanFilter.original:
      return im;
    case ScanFilter.magic:
      return _applyLut(_flatten(im), _lut((v) {
        final lin = _cd((v - 25) / 210, 0.0, 1.0);
        final smooth = lin * lin * (3 - 2 * lin);
        return (0.55 * lin + 0.45 * smooth) * 255;
      }));
    case ScanFilter.blackWhite:
      {
        final flat = _toGrayRgb(_flatten(im));
        return _applyLut(flat, _lut((v) => _smoothstep(125, 185, v.toDouble()) * 255));
      }
    case ScanFilter.grayscale:
      {
        final flat = _toGrayRgb(_flatten(im));
        return _applyLut(flat, _lut((v) => _cd((v - 30) / 205, 0.0, 1.0) * 255));
      }
    case ScanFilter.lighten:
      return _applyLut(im, _lut((v) {
        final lifted = math.pow(v / 255, 0.72).toDouble() * 255;
        return (lifted - 128) * 1.12 + 128 + 6;
      }));
    case ScanFilter.sharp:
      return _sharpen(_applyFilter(im, ScanFilter.magic));
  }
}

/// Brightness and contrast, each -100..100.
_Rgb _adjust(_Rgb im, double brightness, double contrast) {
  if (brightness.abs() < 0.5 && contrast.abs() < 0.5) return im;
  final cf = math.pow(2, contrast / 100).toDouble();
  final br = brightness * 1.5;
  return _applyLut(im, _lut((v) => (v - 128) * cf + 128 + br));
}

// ---------------------------------------------------------------------------
// 4. Put it together
// ---------------------------------------------------------------------------

/// What one scanned page looks like. [quad] are the page corners (fractions).
/// [rotation] is in quarter turns clockwise.
Uint8List renderScan(
  Uint8List jpeg,
  List<double> quad, {
  required int filter,
  double brightness = 0,
  double contrast = 0,
  int rotation = 0,
  int maxSide = 2200,
  int quality = 88,
}) {
  final image = decodeOriented(jpeg);
  if (image == null) throw const FormatException('Unreadable picture');
  final src = _toRgb(image);
  var out = _warp(src, quad, maxSide);
  final f = ScanFilter.values[filter.clamp(0, ScanFilter.values.length - 1)];
  out = _applyFilter(out, f);
  out = _adjust(out, brightness, contrast);
  out = _rotate(out, rotation);
  return _encode(out, quality);
}

/// Small previews of every filter (for the filter strip).
List<Uint8List> renderFilterThumbs(Uint8List jpeg, List<double> quad, {int maxSide = 150}) {
  final image = decodeOriented(jpeg);
  if (image == null) throw const FormatException('Unreadable picture');
  final warped = _warp(_toRgb(image), quad, maxSide);
  return [
    for (final f in ScanFilter.values) _encode(_applyFilter(warped, f), 75),
  ];
}

/// A freshly imported picture, ready for editing.
class ScanImport {
  final Uint8List src; // sharp working copy (long side <= 2400)
  final Uint8List preview; // smaller copy for the screen (<= 1200)
  final int width;
  final int height;
  final List<double> quad;
  const ScanImport(this.src, this.preview, this.width, this.height, this.quad);
}

/// Reads a camera/gallery picture: fixes rotation, makes the working copies
/// and finds the page. null when the file is not a picture.
ScanImport? importScan(Uint8List raw) {
  var image = decodeOriented(raw);
  if (image == null) return null;
  final longest = math.max(image.width, image.height);
  if (longest > 2400) {
    image = resizeKeepRatio(
      image,
      width: image.width >= image.height ? 2400 : null,
      height: image.height > image.width ? 2400 : null,
    );
  }
  final src = encodeJpeg(image, 92);
  var small = image;
  if (math.max(small.width, small.height) > 1200) {
    small = resizeKeepRatio(
      small,
      width: small.width >= small.height ? 1200 : null,
      height: small.height > small.width ? 1200 : null,
    );
  }
  final preview = encodeJpeg(small, 85);
  return ScanImport(src, preview, image.width, image.height, detectDocumentQuad(preview));
}

// ---- background-isolate wrappers ----

Future<ScanImport?> importScanAsync(Uint8List raw) => inBackground(() => importScan(raw));

Future<List<double>> detectQuadAsync(Uint8List jpeg) => inBackground(() => detectDocumentQuad(jpeg));

Future<Uint8List> renderScanAsync(
  Uint8List jpeg,
  List<double> quad, {
  required int filter,
  double brightness = 0,
  double contrast = 0,
  int rotation = 0,
  int maxSide = 2200,
  int quality = 88,
}) =>
    inBackground(() => renderScan(
          jpeg,
          quad,
          filter: filter,
          brightness: brightness,
          contrast: contrast,
          rotation: rotation,
          maxSide: maxSide,
          quality: quality,
        ));

Future<List<Uint8List>> renderFilterThumbsAsync(Uint8List jpeg, List<double> quad) =>
    inBackground(() => renderFilterThumbs(jpeg, quad));
