import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/files/file_helpers.dart';
import '../../../core/scanner/scan_engine.dart';
import '../../../core/scanner/scan_page.dart';
import '../../../core/tools/files/pdf_ops.dart';
import '../files/file_ui.dart';
import 'scan_edit_screen.dart';
import 'scan_text.dart';

/// Document scanner: camera or gallery -> straighten -> filter -> PDF / JPG.
/// Everything happens on the phone. No account, no network, no limits.
class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({super.key});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> with ToolRunner<DocumentScannerScreen> {
  final List<ScanPage> _pages = [];
  final TextEditingController _name = TextEditingController();
  bool _importing = false;
  bool _skipped = false;
  PdfPageMode _mode = PdfPageMode.a4;
  int _quality = 90;

  @override
  void initState() {
    super.initState();
    final d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _name.text = 'Scan_${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
    _recoverLostPicture();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Some phones close the app while the camera is open; the picture is
  /// handed back here when the app starts again.
  Future<void> _recoverLostPicture() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (lost.isEmpty || lost.file == null) return;
      final raw = await lost.file!.readAsBytes();
      if (!mounted) return;
      await _import([raw], openEditor: false);
    } catch (_) {
      // nothing to recover
    }
  }

  Future<void> _camera() async {
    if (_importing) return;
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 3200,
        maxHeight: 3200,
        imageQuality: 92,
      );
      if (shot == null) return;
      final raw = await shot.readAsBytes();
      if (!mounted) return;
      await _import([raw], openEditor: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => errorText = ScanTx.cameraFailed);
    }
  }

  Future<void> _gallery() async {
    if (_importing) return;
    try {
      final files = await pickFiles(extensions: imageExtensions, multiple: true);
      if (files.isEmpty) return;
      final raws = <Uint8List>[];
      for (final f in files) {
        raws.add(await f.readBytes());
      }
      if (!mounted) return;
      await _import(raws, openEditor: raws.length == 1);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = describeError(e));
    }
  }

  Future<void> _import(List<Uint8List> raws, {required bool openEditor}) async {
    setState(() {
      _importing = true;
      errorText = null;
      result = null;
      _skipped = false;
    });
    ScanPage? last;
    try {
      for (final raw in raws) {
        final imported = await importScanAsync(raw);
        if (imported == null) {
          _skipped = true;
          continue;
        }
        final page = ScanPage.fromImport(imported);
        page.thumb = await page.renderThumb();
        if (!mounted) return;
        setState(() => _pages.add(page));
        last = page;
      }
    } catch (e) {
      if (mounted) setState(() => errorText = describeError(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (openEditor && last != null && mounted) {
      await _edit(last);
    }
  }

  Future<void> _edit(ScanPage page) async {
    final number = _pages.indexOf(page) + 1;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ScanEditScreen(page: page, number: number)),
    );
    if (mounted) setState(() => result = null);
  }

  void _move(int index, int by) {
    final to = index + by;
    if (to < 0 || to >= _pages.length) return;
    setState(() {
      final p = _pages.removeAt(index);
      _pages.insert(to, p);
      result = null;
    });
  }

  void _remove(int index) {
    setState(() {
      _pages.removeAt(index);
      result = null;
    });
  }

  String get _baseName {
    final n = baseName(_name.text.trim().isEmpty ? 'Scan' : _name.text.trim());
    return n.isEmpty ? 'Scan' : n;
  }

  Future<void> _makePdf() => runJob(() async {
        final n = _pages.length;
        final jpegs = <Uint8List>[];
        for (var i = 0; i < n; i++) {
          jpegs.add(await _pages[i].renderFinal(quality: 90));
          reportProgress(i + 1, n * 2);
        }
        final pdf = await imagesToPdf(
          jpegs,
          mode: _mode,
          dpi: 200,
          quality: _quality,
          onProgress: (done, total) => reportProgress(n + done, n * 2),
        );
        final out = await writeOutput('$_baseName.pdf', pdf);
        return JobResult(
          [out],
          info: [
            (Tx.pages, '$n'),
            (Tx.fileSize, formatBytes(out.size)),
          ],
        );
      });

  Future<void> _savePictures() => runJob(() async {
        final n = _pages.length;
        final files = <OutputFile>[];
        for (var i = 0; i < n; i++) {
          final jpeg = await _pages[i].renderFinal(quality: _quality);
          files.add(await writeOutput('${_baseName}_${i + 1}.jpg', jpeg));
          reportProgress(i + 1, n);
        }
        return JobResult(files, info: [(Tx.pages, '$n')]);
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ToolPage(
      title: ScanTx.title,
      children: [
        Text(tx(context, ScanTx.intro), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _importing || busy ? null : _camera,
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(tx(context, _pages.isEmpty ? ScanTx.camera : ScanTx.addPage)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importing || busy ? null : _gallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(tx(context, ScanTx.gallery)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
        if (_importing)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 10),
                Text(tx(context, ScanTx.importing)),
              ],
            ),
          ),
        if (_skipped)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: NoteBox(icon: Icons.info_outline_rounded, text: tx(context, ScanTx.notAPicture)),
          ),
        const SizedBox(height: 18),
        if (_pages.isEmpty && !_importing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(Icons.document_scanner_outlined, size: 56, color: scheme.outline),
                const SizedBox(height: 10),
                Text(
                  tx(context, ScanTx.noPages),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else ...[
          Text(tx(context, ScanTx.pagesTitle), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemBuilder: (context, i) => _tile(context, i),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: tx(context, ScanTx.fileName),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ChoiceRow<PdfPageMode>(
            label: ScanTx.pageSize,
            options: [
              (PdfPageMode.a4, ScanTx.a4),
              (PdfPageMode.fitImage, ScanTx.sameAsScan),
            ],
            value: _mode,
            onChanged: (v) => setState(() => _mode = v),
          ),
          ChoiceRow<int>(
            label: ScanTx.quality,
            options: [
              (90, ScanTx.high),
              (80, ScanTx.standard),
              (60, ScanTx.small),
            ],
            value: _quality,
            onChanged: (v) => setState(() => _quality = v),
          ),
          ActionButton(
            label: ScanTx.createPdf,
            icon: Icons.picture_as_pdf_rounded,
            busy: busy,
            enabled: _pages.isNotEmpty && !_importing,
            onPressed: _makePdf,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (busy || _importing) ? null : _savePictures,
              icon: const Icon(Icons.image_outlined),
              label: Text(tx(context, ScanTx.savePictures)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }

  Widget _tile(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    final page = _pages[i];
    final thumb = page.thumb;
    return Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: busy ? null : () => _edit(page),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
                color: scheme.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
              child: thumb == null
                  ? const Center(child: Icon(Icons.image_outlined))
                  : Image.memory(thumb, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
            child: Text('${i + 1}', style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  _edit(page);
                case 'left':
                  _move(i, -1);
                case 'right':
                  _move(i, 1);
                case 'delete':
                  _remove(i);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(tx(context, ScanTx.edit))),
              if (i > 0) PopupMenuItem(value: 'left', child: Text(tx(context, ScanTx.moveEarlier))),
              if (i < _pages.length - 1) PopupMenuItem(value: 'right', child: Text(tx(context, ScanTx.moveLater))),
              PopupMenuItem(value: 'delete', child: Text(tx(context, ScanTx.delete))),
            ],
          ),
        ),
      ],
    );
  }
}
