import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../tools/files/image_ops.dart' show inBackground;

/// Things that can hide inside a PDF.
enum PdfFinding {
  javascript, // scripts
  launch, // can start other programs
  embeddedFile, // attached files
  richMedia, // video / sound
  autoActions, // actions that run when the file is opened
  formSubmit, // sends form data somewhere
  forms, // fillable form fields
  links, // web or other-file links
  comments, // comments and mark-up
  metadata, // author, software, title ...
  xmp, // extra metadata block
  encrypted, // password / encryption present
  compressedParts, // parts packed so tightly that this check cannot see inside
}

enum PdfRisk { low, medium, high }

/// What the quick check found. Nothing leaves the phone: the file is only read here.
class PdfScanReport {
  final Map<PdfFinding, int> counts;

  /// Readable document details (Author, Creator, Producer, Title, Subject, Keywords).
  final Map<String, String> info;
  const PdfScanReport(this.counts, this.info);

  int count(PdfFinding f) => counts[f] ?? 0;
  bool has(PdfFinding f) => count(f) > 0;

  static const Set<PdfFinding> _high = {
    PdfFinding.javascript,
    PdfFinding.launch,
    PdfFinding.embeddedFile,
    PdfFinding.richMedia,
  };

  /// Notes about the check itself, not hidden data.
  static const Set<PdfFinding> _notes = {PdfFinding.encrypted, PdfFinding.compressedParts};

  static bool isHigh(PdfFinding f) => _high.contains(f);
  static bool isNote(PdfFinding f) => _notes.contains(f);

  PdfRisk get risk {
    var medium = false;
    for (final e in counts.entries) {
      if (e.value <= 0 || isNote(e.key)) continue;
      if (isHigh(e.key)) return PdfRisk.high;
      medium = true;
    }
    return medium ? PdfRisk.medium : PdfRisk.low;
  }

  /// The findings to show (without the notes), most serious first.
  List<PdfFinding> get shown => [
        for (final f in PdfFinding.values)
          if (has(f) && !isNote(f)) f,
      ]..sort((a, b) => (isHigh(b) ? 1 : 0).compareTo(isHigh(a) ? 1 : 0));
}

final RegExp _names = RegExp(
  r'/(?:(JavaScript|JS|OpenAction|AA|Launch|EmbeddedFile|FileAttachment|RichMedia|Movie|Sound|'
  r'SubmitForm|ImportData|AcroForm|XFA|URI(?=\s*[(<])|GoToR|GoToE|Encrypt|ObjStm)'
  r'|Subtype\s*/(Text|FreeText|Highlight|Underline|StrikeOut|Squiggly|Stamp|Ink|Caret|Square|Circle|Line|Polygon|PolyLine))'
  r'(?![A-Za-z0-9])',
);

final RegExp _infoKeys = RegExp(
  r'/(Author|Creator|Producer|Title|Subject|Keywords)\s*(\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f\s]*>)',
  dotAll: true,
);

/// Looks through the bytes of a PDF (no PDF engine needed) and lists what is hidden in it.
/// It reads the plain parts of the file; a PDF can also pack parts so tightly
/// that this check cannot see inside ([PdfFinding.compressedParts]).
PdfScanReport scanPdfBytes(Uint8List bytes) {
  final s = latin1.decode(bytes, allowInvalid: true);
  final counts = <PdfFinding, int>{};
  void add(PdfFinding f) => counts[f] = (counts[f] ?? 0) + 1;

  for (final m in _names.allMatches(s)) {
    final simple = m.group(1);
    if (simple != null) {
      switch (simple) {
        case 'JavaScript':
        case 'JS':
          add(PdfFinding.javascript);
        case 'OpenAction':
        case 'AA':
          add(PdfFinding.autoActions);
        case 'Launch':
          add(PdfFinding.launch);
        case 'EmbeddedFile':
        case 'FileAttachment':
          add(PdfFinding.embeddedFile);
        case 'RichMedia':
        case 'Movie':
        case 'Sound':
          add(PdfFinding.richMedia);
        case 'SubmitForm':
        case 'ImportData':
          add(PdfFinding.formSubmit);
        case 'AcroForm':
        case 'XFA':
          add(PdfFinding.forms);
        case 'URI':
        case 'GoToR':
        case 'GoToE':
          add(PdfFinding.links);
        case 'Encrypt':
          add(PdfFinding.encrypted);
        case 'ObjStm':
          add(PdfFinding.compressedParts);
      }
    } else if (m.group(2) != null) {
      add(PdfFinding.comments);
    }
  }

  if (s.contains('<x:xmpmeta') || s.contains('<?xpacket')) {
    counts[PdfFinding.xmp] = 1;
  }

  final info = _readInfo(s);
  if (info.isNotEmpty) counts[PdfFinding.metadata] = info.length;
  return PdfScanReport(counts, info);
}

/// Reads the file inside a background worker (big files do not freeze the screen).
Future<PdfScanReport> scanPdfFile(String path) => inBackground(() => scanPdfBytes(File(path).readAsBytesSync()));

Map<String, String> _readInfo(String s) {
  final refs = RegExp(r'/Info\s+(\d+)\s+(\d+)\s+R').allMatches(s).toList();
  if (refs.isEmpty) return const {};
  final number = refs.last.group(1)!;
  final gen = refs.last.group(2)!;
  final heads = RegExp('(?:^|[\\s>])$number\\s+$gen\\s+obj').allMatches(s).toList();
  if (heads.isEmpty) return const {};
  final start = heads.last.end;
  final end = s.indexOf('endobj', start);
  final body = s.substring(start, end < 0 ? math.min(s.length, start + 4000) : end);
  final out = <String, String>{};
  for (final m in _infoKeys.allMatches(body)) {
    final value = decodePdfString(m.group(2)!);
    if (value.isNotEmpty) out[m.group(1)!] = value;
  }
  return out;
}

/// "(text)" or "<hex>" from a PDF -> readable text (handles escapes and UTF-16).
String decodePdfString(String token) {
  final bytes = <int>[];
  if (token.startsWith('<')) {
    final hex = token.substring(1, token.length - 1).replaceAll(RegExp(r'\s'), '');
    for (var i = 0; i + 1 < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
  } else {
    final inner = token.length >= 2 ? token.substring(1, token.length - 1) : '';
    var i = 0;
    while (i < inner.length) {
      final c = inner.codeUnitAt(i);
      if (c != 0x5C) {
        bytes.add(c & 0xFF);
        i++;
        continue;
      }
      i++; // backslash
      if (i >= inner.length) break;
      final e = inner[i];
      switch (e) {
        case 'n':
          bytes.add(10);
          i++;
        case 'r':
          bytes.add(13);
          i++;
        case 't':
          bytes.add(9);
          i++;
        case 'b':
          bytes.add(8);
          i++;
        case 'f':
          bytes.add(12);
          i++;
        case '\r':
        case '\n':
          i++; // line continuation
        default:
          if (e.codeUnitAt(0) >= 0x30 && e.codeUnitAt(0) <= 0x37) {
            var v = 0;
            var n = 0;
            while (i < inner.length && n < 3 && inner.codeUnitAt(i) >= 0x30 && inner.codeUnitAt(i) <= 0x37) {
              v = v * 8 + (inner.codeUnitAt(i) - 0x30);
              i++;
              n++;
            }
            bytes.add(v & 0xFF);
          } else {
            bytes.add(e.codeUnitAt(0) & 0xFF); // \( \) \\ and others
            i++;
          }
      }
    }
  }
  String text;
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    final units = <int>[];
    for (var i = 2; i + 1 < bytes.length; i += 2) {
      units.add((bytes[i] << 8) | bytes[i + 1]);
    }
    text = String.fromCharCodes(units);
  } else {
    text = String.fromCharCodes(bytes);
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length > 80 ? '${text.substring(0, 80)}…' : text;
}
