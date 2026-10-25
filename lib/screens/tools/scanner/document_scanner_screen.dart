import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/app_services.dart';
import '../../../core/files/file_helpers.dart';
import '../../../core/scanner/scan_engine.dart';
import '../../../core/scanner/scan_page.dart';
import '../../../core/scanner/scan_store.dart';
import '../../../core/tools/files/pdf_ops.dart';
import '../files/file_ui.dart';
import 'scan_edit_screen.dart';
import 'scan_extra_screens.dart';
import 'scan_text.dart';

/// Document scanner: camera or gallery -> straighten -> filter -> PDF / JPG.
/// Everything happens on the phone. No network, no limits. A signed-in person
/// also finds the scan again under "My scans" (saved on the phone only).
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

  // "My scans" (only for a signed-in person)
  String _scanId = ScanStore.newId();
  String? _uid;
  ScanStore? _store;
  Timer? _saveTimer;
  bool _dirty = false;
  Future<void> _saveChain = Future<void>.value();

  static String _defaultName() {
    final d = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Scan_${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }

  @override
  void initState() {
    super.initState();
    _name.text = _defaultName();
    _recoverLostPicture();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = AppScope.of(context).auth.user?.uid;
    if (uid == _uid) return;
    _uid = uid;
    _store = null;
    if (uid != null) {
      ScanStore.forUser(uid).then<void>((store) {
        if (!mounted || _uid != uid) return;
        _store = store;
        if (_pages.isNotEmpty) _scheduleSave();
      }, onError: (Object _) {/* no storage: simply not saved */});
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow(); // reads everything it needs before the controller is released
    _name.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    if (_store == null) return;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1200), _saveNow);
  }

  Future<void> _saveNow() {
    final store = _store;
    if (store == null || !_dirty) return _saveChain;
    _dirty = false;
    final id = _scanId;
    final name = _name.text.trim();
    final pages = List<ScanPage>.of(_pages);
    final mode = _mode.index;
    final quality = _quality;
    _saveChain = _saveChain.then((_) async {
      try {
        await store.save(id: id, name: name, pages: pages, mode: mode, quality: quality);
      } catch (_) {/* the scan stays on screen; it is saved again on the next change */}
    });
    return _saveChain;
  }

  void _clearCurrent() {
    _saveTimer?.cancel();
    _dirty = false;
    _pages.clear();
    _scanId = ScanStore.newId();
    _name.text = _defaultName();
    result = null;
    errorText = null;
    _skipped = false;
  }

  Future<void> _startNew() async {
    if (_pages.isEmpty) return;
    final keptSafe = _store != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx(ctx, ScanTx.newScan)),
        content: Text(tx(ctx, keptSafe ? ScanTx.newScanKept : ScanTx.newScanAsk)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tx(ctx, ScanTx.cancel))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tx(ctx, ScanTx.yes))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _saveNow();
    if (!mounted) return;
    setState(_clearCurrent);
  }

  Future<void> _openLibrary() async {
    final store = _store;
    if (store == null || busy || _importing) return;
    await _saveNow();
    if (!mounted) return;
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScanLibraryScreen(
          store: store,
          currentId: _scanId,
          onDeleted: (id) {
            if (id == _scanId && mounted) setState(_clearCurrent);
          },
        ),
      ),
    );
    if (picked == null || !mounted || picked == _scanId) return;
    await _openSaved(store, picked);
  }

  Future<void> _openSaved(ScanStore store, String id) async {
    setState(() {
      _importing = true;
      errorText = null;
    });
    try {
      final saved = await store.load(id);
      if (saved == null) {
        if (mounted) setState(() => errorText = ScanTx.openFailed);
        return;
      }
      for (final p in saved.pages) {
        p.thumb = await p.renderThumb();
      }
      if (!mounted) return;
      _saveTimer?.cancel();
      _dirty = false;
      setState(() {
        _pages
          ..clear()
          ..addAll(saved.pages);
        _scanId = saved.id;
        _name.text = saved.name;
        _mode = saved.mode >= 0 && saved.mode < PdfPageMode.values.length
            ? PdfPageMode.values[saved.mode]
            : PdfPageMode.a4;
        _quality = const [90, 80, 60].contains(saved.quality) ? saved.quality : 90;
        result = null;
        _skipped = false;
      });
    } catch (_) {
      if (mounted) setState(() => errorText = ScanTx.openFailed);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _reorder() async {
    if (_pages.length < 2 || busy || _importing) return;
    final out = await Navigator.of(context).push<List<ScanPage>>(
      MaterialPageRoute(builder: (_) => ScanReorderScreen(pages: List<ScanPage>.of(_pages))),
    );
    if (out == null || !mounted) return;
    setState(() {
      _pages
        ..clear()
        ..addAll(out);
      result = null;
    });
    _scheduleSave();
  }

  void _previewPdf(OutputFile file) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ScanPdfPreviewScreen(file: file)),
    );
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
        _scheduleSave();
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
    _scheduleSave();
  }

  void _move(int index, int by) {
    final to = index + by;
    if (to < 0 || to >= _pages.length) return;
    setState(() {
      final p = _pages.removeAt(index);
      _pages.insert(to, p);
      result = null;
    });
    _scheduleSave();
  }

  void _remove(int index) {
    setState(() {
      _pages.removeAt(index);
      result = null;
    });
    _scheduleSave();
  }

  String get _baseName {
    final n = baseName(_name.text.trim().isEmpty ? 'Scan' : _name.text.trim());
    return n.isEmpty ? 'Scan' : n;
  }

  Future<void> _makePdf() async {
    await _makePdfJob();
    if (!mounted) return;
    final files = result?.files;
    if (files != null && files.isNotEmpty) {
      _previewPdf(files.first);
    }
    _scheduleSave();
  }

  Future<void> _makePdfJob() => runJob(() async {
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
        if (_uid != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importing || busy ? null : _openLibrary,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(tx(context, ScanTx.myScans)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: NoteBox(icon: Icons.account_circle_outlined, text: tx(context, ScanTx.signInHint)),
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
          Row(
            children: [
              Expanded(
                child: Text(tx(context, ScanTx.pagesTitle), style: Theme.of(context).textTheme.titleMedium),
              ),
              if (_pages.length > 1)
                IconButton(
                  tooltip: tx(context, ScanTx.reorder),
                  icon: const Icon(Icons.swap_vert_rounded),
                  onPressed: (busy || _importing) ? null : _reorder,
                ),
              IconButton(
                tooltip: tx(context, ScanTx.newScan),
                icon: const Icon(Icons.note_add_outlined),
                onPressed: (busy || _importing) ? null : _startNew,
              ),
            ],
          ),
          if (_store != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                tx(context, ScanTx.savedNote),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          const SizedBox(height: 6),
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
            onChanged: (_) => _scheduleSave(),
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
            onChanged: (v) {
              setState(() => _mode = v);
              _scheduleSave();
            },
          ),
          ChoiceRow<int>(
            label: ScanTx.quality,
            options: [
              (90, ScanTx.high),
              (80, ScanTx.standard),
              (60, ScanTx.small),
            ],
            value: _quality,
            onChanged: (v) {
              setState(() => _quality = v);
              _scheduleSave();
            },
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
        if (result != null && result!.files.isNotEmpty && result!.files.first.mimeType == 'application/pdf')
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _previewPdf(result!.files.first),
                icon: const Icon(Icons.visibility_outlined),
                label: Text(tx(context, ScanTx.previewPdf)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
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
