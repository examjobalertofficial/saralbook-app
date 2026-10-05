import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PickedFile {
  final String path;
  final String name;
  final int size;
  const PickedFile(this.path, this.name, this.size);

  Future<Uint8List> readBytes() => File(path).readAsBytes();
}

const List<String> pdfExtensions = ['pdf'];
const List<String> imageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

/// Opens the system file picker (no storage permission needed).
Future<List<PickedFile>> pickFiles({
  required List<String> extensions,
  bool multiple = false,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: multiple,
  );
  if (result == null) return const [];
  return [
    for (final f in result.files)
      if (f.path != null) PickedFile(f.path!, f.name, f.size),
  ];
}

/// A file the app created (kept in a temporary folder until shared/saved).
class OutputFile {
  final String path;
  final String name;
  final int size;
  const OutputFile(this.path, this.name, this.size);

  String get mimeType {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }
}

Future<Directory> _outputDir() async {
  final base = await getTemporaryDirectory();
  final dir = Directory('${base.path}/saralbook_output');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Deletes results older than a day so the phone does not fill up.
Future<void> cleanOldOutputs() async {
  try {
    final dir = await _outputDir();
    final limit = DateTime.now().subtract(const Duration(days: 1));
    await for (final e in dir.list()) {
      if (e is File && (await e.lastModified()).isBefore(limit)) {
        await e.delete();
      }
    }
  } catch (_) {/* cleanup is best effort */}
}

String _safeName(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// "My File.pdf" -> "My_File"
String baseName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return _safeName(dot > 0 ? fileName.substring(0, dot) : fileName);
}

Future<OutputFile> writeOutput(String fileName, Uint8List bytes) async {
  final dir = await _outputDir();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '';
  final name = '${_safeName(stem)}_$stamp$ext';
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return OutputFile(file.path, name, bytes.length);
}

Future<void> shareOutputs(List<OutputFile> files) async {
  await Share.shareXFiles([
    for (final f in files) XFile(f.path, mimeType: f.mimeType, name: f.name),
  ]);
}

/// "Save a copy" using the system save dialog. Returns true if saved.
Future<bool> saveCopy(OutputFile f) async {
  final bytes = await File(f.path).readAsBytes();
  final saved = await FilePicker.platform.saveFile(
    fileName: f.name,
    bytes: bytes,
  );
  return saved != null;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}
