import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../../core/files/file_helpers.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/pdfedit/edit_model.dart';
import '../../../core/pdfedit/edit_paint.dart';
import '../../../core/render/canvas_export.dart';
import '../../../core/tools/files/image_ops.dart' show prepareWorkingImageAsync, readImageSize;
import '../../../core/tools/files/pdf_ops.dart';
import '../../../widgets/page_body.dart';
import '../files/file_ui.dart' show ChoiceRow, NoteBox, PickButton, describeError, tx;
import '../scanner/scan_extra_screens.dart' show ScanPdfPreviewScreen;
import 'edit_pages_screen.dart';
import 'pdf_editor_text.dart';
import 'signature_pad.dart';

/// Most pages the editor keeps in memory at once.
const int kMaxEditPages = 40;

/// Sharpness of the page pictures (dots per inch). The saved PDF keeps the same page size.
const int _dpi = 150;

enum _Tool { select, text, pen, highlight, cover }

class _ExportOptions {
  final int quality;
  final PageNumberPos numbers;
  final String watermark;
  const _ExportOptions(this.quality, this.numbers, this.watermark);
}

const List<int> _palette = [0xFF000000, 0xFF1565C0, 0xFFD32F2F, 0xFF2E7D32, 0xFFFFFFFF];
const List<int> _highlightPalette = [0xFFFFEB3B, 0xFF69F0AE, 0xFFFF80AB, 0xFF80D8FF];

/// Open a PDF and add text, drawings, a signature, pictures or a white patch;
/// re-order, rotate or delete pages; add page numbers or a watermark.
/// The result is saved as a new PDF of page pictures.
class PdfEditorScreen extends StatefulWidget {
  const PdfEditorScreen({super.key});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final List<EditPage> _pages = [];
  int _current = 0;
  String _name = 'document';
  bool _changed = false;

  bool _loading = false;
  bool _saving = false;
  double? _progress;
  LText? _error;

  ui.Image? _base;
  final Map<String, ui.Image> _pictures = {};

  _Tool _tool = _Tool.select;
  String? _selectedId;
  InkItem? _liveInk;
  CoverItem? _liveCover;
  Offset? _coverStart;
  EditItem? _dragItem;

  int _color = _palette.first;
  int _hlColor = _highlightPalette.first;
  int _coverColor = 0xFFFFFFFF;
  double _penWidth = 0.006;

  bool _zoom = false;
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _base?.dispose();
    for (final p in _pictures.values) {
      p.dispose();
    }
    _tc.dispose();
    super.dispose();
  }

  EditPage? get _page => _pages.isEmpty ? null : _pages[_current];

  EditItem? get _selected {
    final page = _page;
    final id = _selectedId;
    if (page == null || id == null) return null;
    for (final it in page.items) {
      if (it.id == id) return it;
    }
    return null;
  }

  // ---------------------------------------------------------------- opening

  Future<void> _open() async {
    final files = await pickFiles(extensions: pdfExtensions);
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    setState(() {
      _loading = true;
      _error = null;
      _progress = null;
    });
    try {
      final summary = await pdfSummary(file.path);
      if (summary.pages > kMaxEditPages) {
        if (mounted) setState(() => _error = EdTx.tooMany(summary.pages, kMaxEditPages));
        return;
      }
      final numbers = <int>[for (var i = 1; i <= summary.pages; i++) i];
      final jpegs = await pdfToImages(
        file.path,
        numbers,
        dpi: _dpi,
        png: false,
        quality: 90,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = total == 0 ? null : done / total);
        },
      );
      final pages = <EditPage>[];
      for (final bytes in jpegs) {
        final size = readImageSize(bytes);
        if (size == null) continue;
        pages.add(EditPage(base: bytes, width: size.width, height: size.height));
      }
      if (pages.isEmpty) throw const FormatException('empty');
      if (!mounted) return;
      _disposeAllImages();
      setState(() {
        _pages
          ..clear()
          ..addAll(pages);
        _current = 0;
        _name = baseName(file.name);
        _changed = false;
        _selectedId = null;
        _tool = _Tool.select;
        _tc.value = Matrix4.identity();
      });
      await _loadBase();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _disposeAllImages() {
    _disposeLater(_base);
    _base = null;
    for (final p in _pictures.values) {
      _disposeLater(p);
    }
    _pictures.clear();
  }

  /// Images are released after the next frame, so a painter never uses a released one.
  void _disposeLater(ui.Image? image) {
    if (image == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  Future<void> _loadBase() async {
    if (_pages.isEmpty) return;
    final index = _current;
    final page = _pages[index];
    final image = await decodeUiImage(page.base);
    if (!mounted || _current != index || index >= _pages.length || _pages[index].key != page.key) {
      image.dispose();
      return;
    }
    final old = _base;
    setState(() => _base = image);
    _disposeLater(old);
  }

  void _switchTo(int i) {
    if (i == _current || i < 0 || i >= _pages.length) return;
    final old = _base;
    setState(() {
      _current = i;
      _selectedId = null;
      _liveInk = null;
      _liveCover = null;
      _dragItem = null;
      _base = null;
    });
    _disposeLater(old);
    _loadBase();
  }

  // ---------------------------------------------------------------- adding

  Offset _frac(Offset p, Size s) => Offset(clamp01(p.dx / s.width), clamp01(p.dy / s.height));

  Future<void> _addTextAt(Offset f) async {
    final page = _page;
    if (page == null) return;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _TextDialog(initial: ''),
    );
    if (text == null || text.trim().isEmpty || !mounted || _page != page) return;
    final item = TextItem(
      text: text.trim(),
      x: math.min(f.dx, 0.8),
      y: math.min(f.dy, 0.94),
      color: _color == 0xFFFFFFFF ? 0xFF000000 : _color,
    );
    setState(() {
      page.items.add(item);
      _selectedId = item.id;
      _tool = _Tool.select;
      _changed = true;
    });
  }

  Future<void> _editSelectedText() async {
    final item = _selected;
    if (item is! TextItem) return;
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(initial: item.text),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() {
      item.text = text.trim();
      _changed = true;
    });
  }

  Future<void> _addSignature() async {
    final page = _page;
    if (page == null) return;
    final sig = await showDialog<SignatureResult>(
      context: context,
      builder: (_) => const SignaturePadDialog(),
    );
    if (sig == null || !mounted) return;
    await _addPicture(sig.png, sig.aspect, width: 0.3);
  }

  Future<void> _addPictureFromGallery() async {
    final page = _page;
    if (page == null) return;
    try {
      final files = await pickFiles(extensions: imageExtensions);
      if (files.isEmpty || !mounted) return;
      final work = await prepareWorkingImageAsync(await files.first.readBytes(), maxSide: 1200);
      if (work == null) throw const FormatException('unreadable');
      if (!mounted) return;
      await _addPicture(work.bytes, work.width / work.height, width: 0.4);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx(context, EdTx.pickFailed))));
      }
    }
  }

  Future<void> _addPicture(Uint8List bytes, double aspect, {required double width}) async {
    final page = _page;
    if (page == null) return;
    final image = await decodeUiImage(bytes);
    if (!mounted || _page != page) {
      image.dispose();
      return;
    }
    final heightFrac = width * page.aspect / aspect;
    final item = PictureItem(
      bytes: bytes,
      x: (1 - width) / 2,
      y: math.max(0.02, math.min(0.5 - heightFrac / 2, 0.98 - heightFrac)),
      w: width,
      aspect: aspect,
    );
    setState(() {
      _pictures[item.id] = image;
      page.items.add(item);
      _selectedId = item.id;
      _tool = _Tool.select;
      _changed = true;
    });
  }

  void _removeItem(EditPage page, EditItem item) {
    page.items.remove(item);
    if (item is PictureItem) {
      _disposeLater(_pictures.remove(item.id));
    }
  }

  void _undo() {
    final page = _page;
    if (page == null || page.items.isEmpty) return;
    setState(() {
      final last = page.items.last;
      _removeItem(page, last);
      if (_selectedId == last.id) _selectedId = null;
    });
  }

  void _deleteSelected() {
    final page = _page;
    final item = _selected;
    if (page == null || item == null) return;
    setState(() {
      _removeItem(page, item);
      _selectedId = null;
      _changed = true;
    });
  }

  // ---------------------------------------------------------------- touches

  void _onTap(Offset p, Size size) {
    final page = _page;
    if (page == null) return;
    if (_tool == _Tool.select) {
      final hit = hitTestItems(page.items, p, size);
      setState(() => _selectedId = hit?.id);
    } else if (_tool == _Tool.text) {
      _addTextAt(_frac(p, size));
    }
  }

  void _onPanStart(Offset p, Size size) {
    final page = _page;
    if (page == null) return;
    final f = _frac(p, size);
    switch (_tool) {
      case _Tool.select:
        final hit = hitTestItems(page.items, p, size);
        setState(() => _selectedId = hit?.id);
        _dragItem = hit;
      case _Tool.pen:
      case _Tool.highlight:
        final hl = _tool == _Tool.highlight;
        setState(() {
          _liveInk = InkItem(
            points: [f.dx, f.dy],
            color: hl ? _hlColor : _color,
            width: hl ? 0.03 : _penWidth,
            highlight: hl,
          );
        });
      case _Tool.cover:
        _coverStart = f;
        setState(() => _liveCover = CoverItem(x: f.dx, y: f.dy, w: 0, h: 0, color: _coverColor));
      case _Tool.text:
        break;
    }
  }

  void _onPanUpdate(Offset p, Offset delta, Size size) {
    final f = _frac(p, size);
    switch (_tool) {
      case _Tool.select:
        final item = _dragItem;
        if (item == null) return;
        final dx = delta.dx / size.width;
        final dy = delta.dy / size.height;
        setState(() {
          if (item is TextItem) {
            item.x = clamp01(item.x + dx);
            item.y = clamp01(item.y + dy);
          } else if (item is PictureItem) {
            item.x = clamp01(item.x + dx);
            item.y = clamp01(item.y + dy);
          } else if (item is CoverItem) {
            item.x = clamp01(item.x + dx);
            item.y = clamp01(item.y + dy);
          }
          _changed = true;
        });
      case _Tool.pen:
      case _Tool.highlight:
        final ink = _liveInk;
        if (ink == null) return;
        setState(() => ink.points.addAll([f.dx, f.dy]));
      case _Tool.cover:
        final start = _coverStart;
        final cover = _liveCover;
        if (start == null || cover == null) return;
        final r = rectFromCorners(start.dx, start.dy, f.dx, f.dy);
        setState(() {
          cover.x = r.x;
          cover.y = r.y;
          cover.w = r.w;
          cover.h = r.h;
        });
      case _Tool.text:
        break;
    }
  }

  void _onPanEnd() {
    final page = _page;
    final ink = _liveInk;
    final cover = _liveCover;
    setState(() {
      if (page != null && ink != null) {
        page.items.add(ink);
        _changed = true;
      }
      if (page != null && cover != null && cover.w > 0.01 && cover.h > 0.01) {
        page.items.add(cover);
        _changed = true;
      }
      _liveInk = null;
      _liveCover = null;
      _coverStart = null;
      _dragItem = null;
    });
  }

  // ---------------------------------------------------------------- pages

  Future<void> _managePages() async {
    if (_pages.isEmpty) return;
    final out = await Navigator.of(context).push<List<EditPage>>(
      MaterialPageRoute(builder: (_) => EditPagesScreen(pages: List<EditPage>.of(_pages))),
    );
    if (out == null || !mounted || out.isEmpty) return;
    // pictures of pages that were removed
    final keep = {for (final p in out) p.key};
    for (final p in _pages) {
      if (keep.contains(p.key)) continue;
      for (final it in p.items) {
        if (it is PictureItem) _disposeLater(_pictures.remove(it.id));
      }
    }
    final currentKey = _pages[_current].key;
    final old = _base;
    setState(() {
      _pages
        ..clear()
        ..addAll(out);
      final at = out.indexWhere((p) => p.key == currentKey);
      _current = at >= 0 ? at : 0;
      _selectedId = null;
      _base = null;
      _changed = true;
    });
    _disposeLater(old);
    await _loadBase();
  }

  // ---------------------------------------------------------------- saving

  Future<void> _save() async {
    if (_pages.isEmpty || _saving) return;
    final opts = await showDialog<_ExportOptions>(
      context: context,
      builder: (_) => const _SaveDialog(),
    );
    if (opts == null || !mounted) return;
    setState(() {
      _saving = true;
      _progress = 0;
      _error = null;
    });
    try {
      await cleanOldOutputs();
      final n = _pages.length;
      final jpegs = <Uint8List>[];
      for (var i = 0; i < n; i++) {
        jpegs.add(await renderEditedPage(
          _pages[i],
          quality: 95,
          numberText: opts.numbers == PageNumberPos.none ? null : pageNumberText(i, 1),
          numberPos: opts.numbers,
          watermark: opts.watermark,
        ));
        if (mounted) setState(() => _progress = (i + 1) / (n * 2));
      }
      final pdf = await imagesToPdf(
        jpegs,
        mode: PdfPageMode.fitImage,
        dpi: _dpi,
        quality: opts.quality,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = 0.5 + (total == 0 ? 0 : done / total) / 2);
        },
      );
      final out = await writeOutput('${_name}_edited.pdf', pdf);
      if (!mounted) return;
      setState(() => _changed = false);
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ScanPdfPreviewScreen(file: out)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx(ctx, EdTx.leaveTitle)),
        content: Text(tx(ctx, EdTx.leaveBody)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tx(ctx, EdTx.stay))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tx(ctx, EdTx.leave))),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------------------------------------------------------- screen

  @override
  Widget build(BuildContext context) {
    final loaded = _pages.isNotEmpty;
    return PopScope(
      canPop: !(loaded && _changed),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tx(context, EdTx.title), style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            if (loaded)
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(tx(context, EdTx.save)),
              ),
          ],
        ),
        body: Stack(
          children: [
            loaded ? _editor(context) : _start(context),
            if (_saving)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: 240,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LinearProgressIndicator(value: _progress),
                              const SizedBox(height: 12),
                              Text(tx(context, EdTx.saving)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _start(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PageBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(tx(context, EdTx.intro), style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          NoteBox(icon: Icons.info_outline_rounded, text: tx(context, EdTx.honest)),
          const SizedBox(height: 16),
          PickButton(
            label: EdTx.choose,
            icon: Icons.picture_as_pdf_rounded,
            onPressed: _loading ? null : _open,
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 6),
                  Text(tx(context, EdTx.opening)),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: NoteBox(icon: Icons.error_outline_rounded, text: tx(context, _error!), error: true),
            ),
        ],
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _pageArea(context),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: NoteBox(icon: Icons.error_outline_rounded, text: tx(context, _error!), error: true),
          ),
        _contextBar(context),
        _toolRow(context),
        _pageStrip(context),
      ],
    );
  }

  Widget _pageArea(BuildContext context) {
    final page = _page!;
    return LayoutBuilder(
      builder: (context, box) {
        var w = box.maxWidth;
        var h = w / page.aspect;
        if (h > box.maxHeight) {
          h = box.maxHeight;
          w = h * page.aspect;
        }
        final size = Size(w, h);
        final items = <EditItem>[
          ...page.items,
          if (_liveCover != null) _liveCover!,
          if (_liveInk != null) _liveInk!,
        ];
        Widget paper({required bool interactive}) {
          final canvas = CustomPaint(
            size: size,
            painter: EditPagePainter(
              base: _base,
              items: items,
              pictures: _pictures,
              selectedId: interactive ? _selectedId : null,
              revision: 0,
            ),
          );
          return SizedBox(
            width: w,
            height: h,
            child: interactive
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: (d) => _onTap(d.localPosition, size),
                    onPanStart: (d) => _onPanStart(d.localPosition, size),
                    onPanUpdate: (d) => _onPanUpdate(d.localPosition, d.delta, size),
                    onPanEnd: (_) => _onPanEnd(),
                    onPanCancel: _onPanEnd,
                    child: canvas,
                  )
                : canvas,
          );
        }

        // Zoom mode: pinch and drag move the view. Edit mode: the same view, but touches edit the page.
        final view = _zoom
            ? InteractiveViewer(
                transformationController: _tc,
                minScale: 1,
                maxScale: 6,
                child: paper(interactive: false),
              )
            : ClipRect(
                child: Transform(
                  transform: _tc.value,
                  child: paper(interactive: true),
                ),
              );
        return Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: SizedBox(width: w, height: h, child: view),
          ),
        );
      },
    );
  }

  /// Options for the tool in use, or the controls of the selected item.
  Widget _contextBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    Widget? child;
    if (_zoom) {
      child = _hint(context, EdTx.hintZoom);
    } else if (selected != null && _tool == _Tool.select) {
      child = _selectedControls(context, selected);
    } else {
      switch (_tool) {
        case _Tool.select:
          child = _hint(context, EdTx.hintSelect);
        case _Tool.text:
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hint(context, EdTx.hintText),
              const SizedBox(height: 6),
              _Swatches(colors: _palette, selected: _color, onPick: (c) => setState(() => _color = c)),
            ],
          );
        case _Tool.pen:
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hint(context, EdTx.hintPen),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Swatches(colors: _palette, selected: _color, onPick: (c) => setState(() => _color = c)),
                  for (final o in [(0.003, EdTx.thin), (0.006, EdTx.medium), (0.012, EdTx.thick)])
                    ChoiceChip(
                      label: Text(tx(context, o.$2)),
                      selected: _penWidth == o.$1,
                      onSelected: (_) => setState(() => _penWidth = o.$1),
                    ),
                ],
              ),
            ],
          );
        case _Tool.highlight:
          child = _Swatches(
            colors: _highlightPalette,
            selected: _hlColor,
            onPick: (c) => setState(() => _hlColor = c),
          );
        case _Tool.cover:
          child = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _hint(context, EdTx.hintCover),
              const SizedBox(height: 6),
              _Swatches(
                colors: _palette,
                selected: _coverColor,
                onPick: (c) => setState(() => _coverColor = c),
              ),
            ],
          );
      }
    }
    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: child,
    );
  }

  Widget _hint(BuildContext context, LText text) => Text(
        tx(context, text),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
      );

  Widget _selectedControls(BuildContext context, EditItem item) {
    final children = <Widget>[];
    if (item is TextItem) {
      children.addAll([
        Row(
          children: [
            Text(tx(context, EdTx.size)),
            Expanded(
              child: Slider(
                min: 0.012,
                max: 0.12,
                value: item.size.clamp(0.012, 0.12).toDouble(),
                onChanged: (v) => setState(() {
                  item.size = v;
                  _changed = true;
                }),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Swatches(
              colors: _palette,
              selected: item.color,
              onPick: (c) => setState(() {
                item.color = c;
                _changed = true;
              }),
            ),
            FilterChip(
              label: Text(tx(context, EdTx.bold)),
              selected: item.bold,
              onSelected: (v) => setState(() {
                item.bold = v;
                _changed = true;
              }),
            ),
            TextButton.icon(
              onPressed: _editSelectedText,
              icon: const Icon(Icons.edit_outlined),
              label: Text(tx(context, EdTx.edit)),
            ),
          ],
        ),
      ]);
    } else if (item is PictureItem) {
      children.add(
        Row(
          children: [
            Text(tx(context, EdTx.size)),
            Expanded(
              child: Slider(
                min: 0.05,
                max: 1.0,
                value: item.w.clamp(0.05, 1.0).toDouble(),
                onChanged: (v) => setState(() {
                  item.w = v;
                  _changed = true;
                }),
              ),
            ),
          ],
        ),
      );
    } else if (item is CoverItem) {
      children.add(
        _Swatches(
          colors: _palette,
          selected: item.color,
          onPick: (c) => setState(() {
            item.color = c;
            _changed = true;
          }),
        ),
      );
    }
    children.add(
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _deleteSelected,
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(tx(context, EdTx.delete)),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        ),
      ),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _toolRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tool(IconData icon, LText label, bool on, VoidCallback onTap, {bool enabled = true}) {
      final color = !enabled ? scheme.outline : (on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant);
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: on ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(tx(context, label), style: TextStyle(fontSize: 11, color: color), maxLines: 1),
            ],
          ),
        ),
      );
    }

    void pick(_Tool t) => setState(() {
          _tool = t;
          _zoom = false;
          if (t != _Tool.select) _selectedId = null;
        });

    final canUndo = (_page?.items.isNotEmpty ?? false);
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            tool(Icons.open_with_rounded, EdTx.select, !_zoom && _tool == _Tool.select, () => pick(_Tool.select)),
            tool(Icons.text_fields_rounded, EdTx.text, !_zoom && _tool == _Tool.text, () => pick(_Tool.text)),
            tool(Icons.edit_rounded, EdTx.pen, !_zoom && _tool == _Tool.pen, () => pick(_Tool.pen)),
            tool(Icons.border_color_rounded, EdTx.highlight, !_zoom && _tool == _Tool.highlight, () => pick(_Tool.highlight)),
            tool(Icons.crop_square_rounded, EdTx.cover, !_zoom && _tool == _Tool.cover, () => pick(_Tool.cover)),
            tool(Icons.draw_rounded, EdTx.signature, false, _addSignature),
            tool(Icons.add_photo_alternate_outlined, EdTx.picture, false, _addPictureFromGallery),
            tool(Icons.undo_rounded, EdTx.undo, false, _undo, enabled: canUndo),
            tool(_zoom ? Icons.zoom_out_map_rounded : Icons.zoom_in_rounded, EdTx.zoom, _zoom, () => setState(() => _zoom = !_zoom)),
            tool(Icons.fit_screen_rounded, EdTx.fit, false, () => setState(() => _tc.value = Matrix4.identity())),
            tool(Icons.view_agenda_outlined, EdTx.pagesBtn, false, _managePages),
          ],
        ),
      ),
    );
  }

  Widget _pageStrip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 76,
      color: scheme.surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        itemCount: _pages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final on = i == _current;
          return GestureDetector(
            onTap: () => _switchTo(i),
            child: Container(
              width: 46,
              decoration: BoxDecoration(
                border: Border.all(color: on ? scheme.primary : scheme.outlineVariant, width: on ? 2.5 : 1),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_pages[i].base, fit: BoxFit.cover, cacheWidth: 120, gaplessPlayback: true),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(6)),
                      child: Text('${i + 1}', style: TextStyle(color: scheme.onPrimary, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A row of round colour buttons.
class _Swatches extends StatelessWidget {
  final List<int> colors;
  final int selected;
  final ValueChanged<int> onPick;
  const _Swatches({required this.colors, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in colors)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: c == selected ? scheme.primary : scheme.outline,
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TextDialog extends StatefulWidget {
  final String initial;
  const _TextDialog({required this.initial});

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tx(context, EdTx.typeText)),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tx(context, EdTx.cancel))),
        FilledButton(onPressed: () => Navigator.of(context).pop(_c.text), child: Text(tx(context, EdTx.add))),
      ],
    );
  }
}

class _SaveDialog extends StatefulWidget {
  const _SaveDialog();

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  int _quality = 85;
  PageNumberPos _numbers = PageNumberPos.none;
  final TextEditingController _mark = TextEditingController();

  @override
  void dispose() {
    _mark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tx(context, EdTx.saveTitle)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChoiceRow<int>(
              label: EdTx.quality,
              options: [(92, EdTx.high), (85, EdTx.standard), (65, EdTx.small)],
              value: _quality,
              onChanged: (v) => setState(() => _quality = v),
            ),
            ChoiceRow<PageNumberPos>(
              label: EdTx.numbers,
              options: [
                (PageNumberPos.none, EdTx.numNone),
                (PageNumberPos.bottomCenter, EdTx.numBottomCenter),
                (PageNumberPos.bottomRight, EdTx.numBottomRight),
                (PageNumberPos.bottomLeft, EdTx.numBottomLeft),
                (PageNumberPos.topRight, EdTx.numTopRight),
              ],
              value: _numbers,
              onChanged: (v) => setState(() => _numbers = v),
            ),
            TextField(
              controller: _mark,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: tx(context, EdTx.watermark),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tx(context, EdTx.cancel))),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ExportOptions(_quality, _numbers, _mark.text.trim())),
          child: Text(tx(context, EdTx.save)),
        ),
      ],
    );
  }
}
