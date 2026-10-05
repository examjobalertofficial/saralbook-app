import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;

import '../../../core/files/file_helpers.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/tools/files/page_ranges.dart';
import '../../../core/tools/files/pdf_ops.dart';
import 'file_ui.dart';

// ======================= PDF viewer =======================

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PickedFile? _file;

  Future<void> _pick() async {
    final f = await pickFiles(extensions: pdfExtensions);
    if (f.isNotEmpty && mounted) setState(() => _file = f.first);
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) {
      return ToolPage(
        title: t('PDF Viewer', 'PDF व्यूअर'),
        children: [PickButton(label: Tx.choosePdf, onPressed: _pick)],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: tx(context, Tx.change),
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: _pick,
          ),
        ],
      ),
      body: PdfViewer.file(file.path, key: ValueKey(file.path)),
    );
  }
}

// ======================= Page counter =======================

class PdfPageCounterScreen extends StatefulWidget {
  const PdfPageCounterScreen({super.key});

  @override
  State<PdfPageCounterScreen> createState() => _PdfPageCounterScreenState();
}

class _PdfPageCounterScreenState extends State<PdfPageCounterScreen> with ToolRunner {
  PickedFile? _file;
  PdfSummary? _summary;

  Future<void> _pick() async {
    final f = await pickFiles(extensions: pdfExtensions);
    if (f.isEmpty || !mounted) return;
    setState(() {
      _file = f.first;
      _summary = null;
      errorText = null;
    });
    setState(() => busy = true);
    try {
      final s = await pdfSummary(f.first.path);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) setState(() => errorText = describeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _sizeName(PdfSummary s) {
    bool near(double a, double b) => (a - b).abs() < 3;
    final w = s.widthMm, h = s.heightMm;
    if ((near(w, 210) && near(h, 297)) || (near(w, 297) && near(h, 210))) return 'A4';
    if ((near(w, 148) && near(h, 210)) || (near(w, 210) && near(h, 148))) return 'A5';
    if ((near(w, 216) && near(h, 279)) || (near(w, 279) && near(h, 216))) return 'Letter';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final scheme = Theme.of(context).colorScheme;
    return ToolPage(
      title: t('PDF Page Counter', 'PDF पेज काउंटर'),
      children: [
        PickButton(label: Tx.choosePdf, onPressed: busy ? null : _pick),
        if (_file != null) ...[
          const SizedBox(height: 12),
          PickedCard(file: _file!, icon: Icons.picture_as_pdf_rounded),
        ],
        ...statusWidgets(context),
        if (s != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              elevation: 0,
              color: scheme.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.pages}',
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                    ),
                    Text(tx(context, Tx.pages), style: TextStyle(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 12),
                    Text(
                      '${tx(context, Tx.pageSize)}: ${s.widthMm.round()} × ${s.heightMm.round()} mm ${_sizeName(s)}',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                    Text(
                      '${tx(context, Tx.fileSize)}: ${formatBytes(_file!.size)}',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ======================= Merge =======================

class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> with ToolRunner {
  List<PickedFile> _files = [];

  Future<void> _add() async {
    final picked = await pickFiles(extensions: pdfExtensions, multiple: true);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      final known = _files.map((e) => e.path).toSet();
      _files = [..._files, for (final f in picked) if (!known.contains(f.path)) f];
      clearResult();
    });
  }

  Future<void> _merge() => runJob(() async {
        final bytes = await mergePdfs([for (final f in _files) f.path], onProgress: reportProgress);
        final out = await writeOutput('merged.pdf', bytes);
        final summary = await pdfSummary(out.path);
        return JobResult([out], info: [(Tx.pages, '${summary.pages}'), (Tx.fileSize, formatBytes(out.size))]);
      });

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: t('Merge PDF', 'PDF मर्ज करें'),
      children: [
        PickButton(
          label: _files.isEmpty ? Tx.choosePdfs : Tx.addMore,
          icon: Icons.add_rounded,
          onPressed: busy ? null : _add,
        ),
        if (_files.isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderedFileList(
            files: _files,
            images: false,
            onChanged: (l) => setState(() {
              _files = l;
              clearResult();
            }),
          ),
          const SizedBox(height: 8),
          ActionButton(
            label: t('Merge', 'मर्ज करें'),
            icon: Icons.merge_type_rounded,
            enabled: _files.length >= 2,
            busy: busy,
            onPressed: _merge,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Split / extract =======================

enum SplitMode { extract, each, ranges }

class PdfSplitScreen extends StatefulWidget {
  const PdfSplitScreen({super.key});

  @override
  State<PdfSplitScreen> createState() => _PdfSplitScreenState();
}

class _PdfSplitScreenState extends State<PdfSplitScreen> with ToolRunner {
  PickedFile? _file;
  PdfSummary? _summary;
  SplitMode _mode = SplitMode.extract;
  final TextEditingController _range = TextEditingController();

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickFiles(extensions: pdfExtensions);
    if (f.isEmpty || !mounted) return;
    setState(() {
      _file = f.first;
      _summary = null;
      clearResult();
    });
    try {
      final s = await pdfSummary(f.first.path);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) setState(() => errorText = describeError(e));
    }
  }

  Future<void> _split() async {
    final pages = _summary!.pages;
    List<List<int>>? groups;
    switch (_mode) {
      case SplitMode.each:
        groups = [for (var i = 1; i <= pages; i++) [i]];
        if (groups.length > maxRasterPages) groups = null;
      case SplitMode.extract:
        final list = parsePageList(_range.text, pages);
        groups = list == null ? null : [list];
      case SplitMode.ranges:
        groups = parsePageGroups(_range.text, pages);
    }
    if (groups == null) {
      setState(() => errorText = Tx.errRange);
      return;
    }
    final base = baseName(_file!.name);
    await runJob(() async {
      final parts = await splitPdf(_file!.path, groups!, onProgress: reportProgress);
      final files = <OutputFile>[];
      for (var i = 0; i < parts.length; i++) {
        final name = parts.length == 1 ? '${base}_pages.pdf' : '${base}_part${i + 1}.pdf';
        files.add(await writeOutput(name, parts[i]));
      }
      return JobResult(files);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final needsRange = _mode != SplitMode.each;
    return ToolPage(
      title: t('Split PDF', 'PDF स्प्लिट करें'),
      children: [
        PickButton(label: Tx.choosePdf, onPressed: busy ? null : _pick),
        if (_file != null) ...[
          const SizedBox(height: 12),
          PickedCard(
            file: _file!,
            icon: Icons.picture_as_pdf_rounded,
            trailing: s == null ? null : Text('${s.pages} ${tx(context, Tx.pages)}'),
          ),
        ],
        if (s != null) ...[
          const SizedBox(height: 16),
          ChoiceRow<SplitMode>(
            label: t('What do you want?', 'आप क्या चाहते हैं?'),
            value: _mode,
            options: [
              (SplitMode.extract, t('Extract pages', 'पेज निकालें')),
              (SplitMode.each, t('Every page separately', 'हर पेज अलग')),
              (SplitMode.ranges, t('Separate files by range', 'रेंज के अनुसार अलग फ़ाइलें')),
            ],
            onChanged: (m) => setState(() {
              _mode = m;
              clearResult();
            }),
          ),
          if (needsRange)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _range,
                decoration: InputDecoration(
                  labelText: tx(context, Tx.pageNumbers),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => errorText = null),
              ),
            ),
          ActionButton(
            label: t('Split', 'स्प्लिट करें'),
            icon: Icons.call_split_rounded,
            enabled: !needsRange || _range.text.trim().isNotEmpty,
            busy: busy,
            onPressed: _split,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Compress =======================

class PdfCompressScreen extends StatefulWidget {
  const PdfCompressScreen({super.key});

  @override
  State<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends State<PdfCompressScreen> with ToolRunner {
  PickedFile? _file;
  int _level = 1; // 0 light, 1 balanced, 2 strong
  static const _dpi = [130, 100, 72];
  static const _quality = [75, 60, 45];

  Future<void> _pick() async {
    final f = await pickFiles(extensions: pdfExtensions);
    if (f.isEmpty || !mounted) return;
    setState(() {
      _file = f.first;
      clearResult();
    });
  }

  Future<void> _compress() => runJob(() async {
        final file = _file!;
        final bytes = await compressPdf(
          file.path,
          dpi: _dpi[_level],
          quality: _quality[_level],
          onProgress: reportProgress,
        );
        final out = await writeOutput('${baseName(file.name)}_compressed.pdf', bytes);
        final saved = file.size == 0 ? 0 : ((1 - out.size / file.size) * 100).round();
        return JobResult(
          [out],
          info: [
            (Tx.before, formatBytes(file.size)),
            (Tx.after, formatBytes(out.size)),
            (Tx.saving, '$saved%'),
          ],
          warnings: out.size >= file.size ? [Tx.notSmaller] : const [],
        );
      });

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: t('Compress PDF', 'PDF कंप्रेस करें'),
      children: [
        PickButton(label: Tx.choosePdf, onPressed: busy ? null : _pick),
        if (_file != null) ...[
          const SizedBox(height: 12),
          PickedCard(file: _file!, icon: Icons.picture_as_pdf_rounded),
          const SizedBox(height: 16),
          ChoiceRow<int>(
            label: t('Compression', 'कंप्रेशन'),
            value: _level,
            options: [
              (0, t('Light (best quality)', 'हल्का (बेहतर क्वालिटी)')),
              (1, t('Balanced', 'संतुलित')),
              (2, t('Strong (smallest)', 'तेज़ (सबसे छोटा)')),
            ],
            onChanged: (v) => setState(() {
              _level = v;
              clearResult();
            }),
          ),
          NoteBox(
            icon: Icons.info_outline_rounded,
            text: tx(
              context,
              t(
                'Each page is saved as a picture to make the file smaller, so text can no longer be selected or searched. Best for scanned documents.',
                'फ़ाइल छोटी करने के लिए हर पेज फ़ोटो के रूप में सेव होता है, इसलिए टेक्स्ट सेलेक्ट या सर्च नहीं हो सकेगा। स्कैन किए दस्तावेज़ों के लिए सबसे अच्छा।',
              ),
            ),
          ),
          const SizedBox(height: 14),
          ActionButton(
            label: t('Compress', 'कंप्रेस करें'),
            icon: Icons.compress_rounded,
            busy: busy,
            onPressed: _compress,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Pictures -> PDF =======================

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> with ToolRunner {
  List<PickedFile> _files = [];
  PdfPageMode _mode = PdfPageMode.a4;
  int _quality = 1;
  static const _dpi = [100, 150, 200];
  static const _jpeg = [70, 80, 88];

  Future<void> _add() async {
    final picked = await pickFiles(extensions: imageExtensions, multiple: true);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      final known = _files.map((e) => e.path).toSet();
      _files = [..._files, for (final f in picked) if (!known.contains(f.path)) f];
      clearResult();
    });
  }

  Future<void> _create() => runJob(() async {
        final images = <Uint8List>[];
        for (final f in _files) {
          images.add(await f.readBytes());
        }
        final bytes = await imagesToPdf(
          images,
          mode: _mode,
          dpi: _dpi[_quality],
          quality: _jpeg[_quality],
          onProgress: reportProgress,
        );
        final out = await writeOutput('pictures.pdf', bytes);
        return JobResult([out], info: [(Tx.pages, '${images.length}'), (Tx.fileSize, formatBytes(out.size))]);
      });

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: t('Pictures to PDF', 'फ़ोटो से PDF'),
      children: [
        PickButton(
          label: _files.isEmpty ? Tx.chooseImages : Tx.addMore,
          icon: Icons.add_photo_alternate_outlined,
          onPressed: busy ? null : _add,
        ),
        if (_files.isNotEmpty) ...[
          const SizedBox(height: 12),
          OrderedFileList(
            files: _files,
            images: true,
            onChanged: (l) => setState(() {
              _files = l;
              clearResult();
            }),
          ),
          const SizedBox(height: 8),
          ChoiceRow<PdfPageMode>(
            label: t('Page size', 'पेज का आकार'),
            value: _mode,
            options: [
              (PdfPageMode.a4, t('A4 page', 'A4 पेज')),
              (PdfPageMode.fitImage, t('Same as picture', 'फ़ोटो के बराबर')),
            ],
            onChanged: (v) => setState(() {
              _mode = v;
              clearResult();
            }),
          ),
          ChoiceRow<int>(
            label: t('Quality', 'क्वालिटी'),
            value: _quality,
            options: [
              (0, t('Small file', 'छोटी फ़ाइल')),
              (1, t('Balanced', 'संतुलित')),
              (2, t('Best quality', 'सबसे अच्छी क्वालिटी')),
            ],
            onChanged: (v) => setState(() {
              _quality = v;
              clearResult();
            }),
          ),
          ActionButton(
            label: t('Create PDF', 'PDF बनाएं'),
            icon: Icons.picture_as_pdf_rounded,
            busy: busy,
            onPressed: _create,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= PDF -> pictures =======================

class PdfToImagesScreen extends StatefulWidget {
  const PdfToImagesScreen({super.key});

  @override
  State<PdfToImagesScreen> createState() => _PdfToImagesScreenState();
}

class _PdfToImagesScreenState extends State<PdfToImagesScreen> with ToolRunner {
  PickedFile? _file;
  PdfSummary? _summary;
  bool _png = false;
  int _dpi = 150;
  final TextEditingController _range = TextEditingController(text: 'all');

  @override
  void dispose() {
    _range.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickFiles(extensions: pdfExtensions);
    if (f.isEmpty || !mounted) return;
    setState(() {
      _file = f.first;
      _summary = null;
      clearResult();
    });
    try {
      final s = await pdfSummary(f.first.path);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) setState(() => errorText = describeError(e));
    }
  }

  Future<void> _convert() async {
    final pages = parsePageList(_range.text, _summary!.pages);
    if (pages == null) {
      setState(() => errorText = Tx.errRange);
      return;
    }
    final base = baseName(_file!.name);
    await runJob(() async {
      final images = await pdfToImages(
        _file!.path,
        pages,
        dpi: _dpi,
        png: _png,
        onProgress: reportProgress,
      );
      final files = <OutputFile>[];
      for (var i = 0; i < images.length; i++) {
        final n = pages[i].toString().padLeft(3, '0');
        files.add(await writeOutput('${base}_page$n.${_png ? 'png' : 'jpg'}', images[i]));
      }
      return JobResult(files);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return ToolPage(
      title: t('PDF to Pictures', 'PDF से फ़ोटो'),
      children: [
        PickButton(label: Tx.choosePdf, onPressed: busy ? null : _pick),
        if (_file != null) ...[
          const SizedBox(height: 12),
          PickedCard(
            file: _file!,
            icon: Icons.picture_as_pdf_rounded,
            trailing: s == null ? null : Text('${s.pages} ${tx(context, Tx.pages)}'),
          ),
        ],
        if (s != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _range,
              decoration: InputDecoration(
                labelText: tx(context, Tx.pageNumbers),
                helperText: 'all',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => errorText = null),
            ),
          ),
          ChoiceRow<bool>(
            label: t('Format', 'फ़ॉर्मैट'),
            value: _png,
            options: [(false, Tx.jpg), (true, Tx.png)],
            onChanged: (v) => setState(() {
              _png = v;
              clearResult();
            }),
          ),
          ChoiceRow<int>(
            label: t('Sharpness (DPI)', 'शार्पनेस (DPI)'),
            value: _dpi,
            options: [
              (100, t('100 – small', '100 – छोटा')),
              (150, t('150 – normal', '150 – सामान्य')),
              (200, t('200 – sharp', '200 – शार्प')),
            ],
            onChanged: (v) => setState(() {
              _dpi = v;
              clearResult();
            }),
          ),
          ActionButton(
            label: t('Convert', 'बदलें'),
            icon: Icons.photo_library_outlined,
            busy: busy,
            onPressed: _convert,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}
