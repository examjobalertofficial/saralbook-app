import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'scan_engine.dart';
import 'scan_page.dart';

/// A saved scan as shown in "My scans".
class SavedScanInfo {
  final String id;
  final String name;
  final DateTime updated;
  final int pages;
  final int bytes;

  /// The first page's small picture (null if missing).
  final File? cover;
  const SavedScanInfo({
    required this.id,
    required this.name,
    required this.updated,
    required this.pages,
    required this.bytes,
    required this.cover,
  });
}

/// A saved scan opened again.
class LoadedScan {
  final String id;
  final String name;
  final int mode;
  final int quality;
  final List<ScanPage> pages;
  const LoadedScan({
    required this.id,
    required this.name,
    required this.mode,
    required this.quality,
    required this.pages,
  });
}

/// "My scans": every scan a signed-in person works on is kept on the phone
/// (their own folder, nothing is uploaded) so they can come back, re-order
/// pages or make the PDF again. The pictures are stored once per page; only a
/// tiny text file changes when the person edits.
class ScanStore {
  ScanStore(this.root);

  final Directory root;

  static Future<ScanStore> forUser(String uid) async {
    final base = await getApplicationDocumentsDirectory();
    return ScanStore(Directory('${base.path}/saralbook_scans/${safeFolder(uid)}'));
  }

  /// Folder names can only hold letters, digits, "_" and "-".
  static String safeFolder(String raw) {
    final s = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return s.isEmpty ? 'user' : s;
  }

  static String newId() => DateTime.now().millisecondsSinceEpoch.toString();

  Directory _dir(String id) => Directory('${root.path}/${safeFolder(id)}');

  static String _srcName(String key) => '${safeFolder(key)}_s.jpg';
  static String _prevName(String key) => '${safeFolder(key)}_v.jpg';

  /// The text part of one page (corners, filter and so on).
  static Map<String, Object> pageToMap(ScanPage p) => {
        'key': p.key,
        'w': p.width,
        'h': p.height,
        'quad': p.quad,
        'filter': p.filter,
        'b': p.brightness,
        'c': p.contrast,
        'rot': p.rotation,
      };

  static List<double> _cleanQuad(Object? raw) {
    if (raw is List && raw.length == 8) {
      final out = <double>[];
      for (final v in raw) {
        if (v is! num || !v.isFinite) return fullPageQuad();
        out.add(v.toDouble().clamp(0.0, 1.0).toDouble());
      }
      return out;
    }
    return fullPageQuad();
  }

  static int _int(Object? v, int fallback, {int min = 0, int max = 1 << 30}) {
    if (v is num && v.isFinite) {
      final i = v.toInt();
      return i < min ? min : (i > max ? max : i);
    }
    return fallback;
  }

  static double _double(Object? v, double min, double max) {
    if (v is num && v.isFinite) {
      final d = v.toDouble();
      return d < min ? min : (d > max ? max : d);
    }
    return 0;
  }

  /// Saves (or updates) one scan. Pictures already on disk are not written again.
  Future<void> save({
    required String id,
    required String name,
    required List<ScanPage> pages,
    required int mode,
    required int quality,
  }) async {
    if (pages.isEmpty) {
      await delete(id);
      return;
    }
    final dir = _dir(id);
    await dir.create(recursive: true);
    final keep = <String>{'meta.json'};
    for (final p in pages) {
      final s = File('${dir.path}/${_srcName(p.key)}');
      final v = File('${dir.path}/${_prevName(p.key)}');
      keep
        ..add(_srcName(p.key))
        ..add(_prevName(p.key));
      if (!await s.exists()) await s.writeAsBytes(p.src, flush: true);
      if (!await v.exists()) await v.writeAsBytes(p.preview, flush: true);
    }
    final meta = jsonEncode({
      'v': 1,
      'name': name,
      'updated': DateTime.now().millisecondsSinceEpoch,
      'mode': mode,
      'quality': quality,
      'pages': [for (final p in pages) pageToMap(p)],
    });
    final tmp = File('${dir.path}/meta.tmp');
    await tmp.writeAsString(meta, flush: true);
    await tmp.rename('${dir.path}/meta.json');
    // pictures of pages the person removed
    await for (final e in dir.list()) {
      if (e is File) {
        final n = e.uri.pathSegments.last;
        if (!keep.contains(n)) {
          try {
            await e.delete();
          } catch (_) {/* best effort */}
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _readMeta(Directory dir) async {
    try {
      final f = File('${dir.path}/meta.json');
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString());
      return m is Map<String, dynamic> ? m : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> exists(String id) => File('${_dir(id).path}/meta.json').exists();

  Future<List<SavedScanInfo>> list() async {
    final out = <SavedScanInfo>[];
    if (!await root.exists()) return out;
    await for (final d in root.list()) {
      if (d is! Directory) continue;
      final m = await _readMeta(d);
      if (m == null) continue;
      final pages = m['pages'];
      if (pages is! List || pages.isEmpty) continue;
      var bytes = 0;
      await for (final e in d.list()) {
        if (e is File) bytes += await e.length();
      }
      final first = pages.first;
      File? cover;
      if (first is Map && first['key'] is String) {
        final c = File('${d.path}/${_prevName(first['key'] as String)}');
        if (await c.exists()) cover = c;
      }
      out.add(SavedScanInfo(
        id: d.uri.pathSegments.where((s) => s.isNotEmpty).last,
        name: (m['name'] is String && (m['name'] as String).isNotEmpty) ? m['name'] as String : 'Scan',
        updated: DateTime.fromMillisecondsSinceEpoch(_int(m['updated'], 0)),
        pages: pages.length,
        bytes: bytes,
        cover: cover,
      ));
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  Future<LoadedScan?> load(String id) async {
    final dir = _dir(id);
    final m = await _readMeta(dir);
    if (m == null) return null;
    final raw = m['pages'];
    if (raw is! List) return null;
    final pages = <ScanPage>[];
    for (final e in raw) {
      if (e is! Map || e['key'] is! String) continue;
      final key = e['key'] as String;
      final s = File('${dir.path}/${_srcName(key)}');
      final v = File('${dir.path}/${_prevName(key)}');
      if (!await s.exists() || !await v.exists()) continue;
      pages.add(ScanPage(
        src: Uint8List.fromList(await s.readAsBytes()),
        preview: Uint8List.fromList(await v.readAsBytes()),
        width: _int(e['w'], 1, min: 1),
        height: _int(e['h'], 1, min: 1),
        quad: _cleanQuad(e['quad']),
        filter: _int(e['filter'], 1, max: ScanFilter.values.length - 1),
        brightness: _double(e['b'], -100, 100),
        contrast: _double(e['c'], -100, 100),
        rotation: _int(e['rot'], 0) % 4,
        key: key,
      ));
    }
    if (pages.isEmpty) return null;
    return LoadedScan(
      id: id,
      name: m['name'] is String ? m['name'] as String : 'Scan',
      mode: _int(m['mode'], 0),
      quality: _int(m['quality'], 90, min: 30, max: 100),
      pages: pages,
    );
  }

  Future<void> delete(String id) async {
    final dir = _dir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Everything of this person (used by "Delete my data").
  Future<void> deleteAll() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
