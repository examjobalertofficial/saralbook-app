import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/scanner/scan_engine.dart';
import '../../../core/scanner/scan_page.dart';
import '../../../core/l10n/ltext.dart';
import '../files/file_ui.dart';
import 'quad_editor.dart';
import 'scan_text.dart';

enum _Mode { crop, filter, adjust }

/// Edit one scanned page: move the corners, pick a filter, adjust light.
/// Changes are written straight into [page]; the screen returns true.
class ScanEditScreen extends StatefulWidget {
  final ScanPage page;
  final int number;
  const ScanEditScreen({super.key, required this.page, required this.number});

  @override
  State<ScanEditScreen> createState() => _ScanEditScreenState();
}

class _ScanEditScreenState extends State<ScanEditScreen> {
  _Mode _mode = _Mode.crop;
  Uint8List? _processed;
  List<Uint8List>? _thumbs;
  bool _rendering = false;
  bool _saving = false;
  int _gen = 0;

  ScanPage get _p => widget.page;

  @override
  void initState() {
    super.initState();
    _render();
    _renderThumbs();
  }

  Future<void> _render() async {
    final gen = ++_gen;
    setState(() => _rendering = true);
    try {
      final bytes = await renderScanAsync(
        _p.preview,
        _p.quad,
        filter: _p.filter,
        brightness: _p.brightness,
        contrast: _p.contrast,
        rotation: _p.rotation,
        maxSide: 1100,
        quality: 82,
      );
      if (!mounted || gen != _gen) return;
      setState(() => _processed = bytes);
    } catch (_) {
      // keep the last picture
    } finally {
      if (mounted && gen == _gen) setState(() => _rendering = false);
    }
  }

  Future<void> _renderThumbs() async {
    try {
      final list = await renderFilterThumbsAsync(_p.preview, _p.quad);
      if (!mounted) return;
      setState(() => _thumbs = list);
    } catch (_) {
      // the strip simply shows names
    }
  }

  void _setMode(_Mode m) {
    if (m == _mode) return;
    final leavingCrop = _mode == _Mode.crop;
    setState(() => _mode = m);
    if (leavingCrop) {
      _render();
      _renderThumbs();
    }
  }

  Future<void> _autoDetect() async {
    setState(() => _rendering = true);
    try {
      final q = await detectQuadAsync(_p.preview);
      if (!mounted) return;
      setState(() => _p.quad = List<double>.of(q));
    } finally {
      if (mounted) setState(() => _rendering = false);
    }
  }

  void _rotate(int dir) {
    setState(() => _p.rotation = (_p.rotation + dir + 4) % 4);
    _render();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      _p.thumb = await _p.renderThumb();
    } catch (_) {
      // keep the old small picture
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${tx(context, ScanTx.editTitle)} ${widget.number}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _finish,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: Text(tx(context, ScanTx.done)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: scheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(14),
                child: _mode == _Mode.crop
                    ? QuadEditor(
                        image: _p.preview,
                        aspect: _p.width / _p.height,
                        quad: _p.quad,
                        onChanged: (q) => setState(() => _p.quad = q),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_processed != null)
                            InteractiveViewer(
                              maxScale: 4,
                              child: Image.memory(_processed!, fit: BoxFit.contain, gaplessPlayback: true),
                            ),
                          if (_rendering) const CircularProgressIndicator(),
                        ],
                      ),
              ),
            ),
            _controls(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Mode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: _Mode.crop, icon: const Icon(Icons.crop_rounded), label: Text(tx(context, ScanTx.tabCrop))),
                    ButtonSegment(value: _Mode.filter, icon: const Icon(Icons.auto_fix_high_rounded), label: Text(tx(context, ScanTx.tabFilter))),
                    ButtonSegment(value: _Mode.adjust, icon: const Icon(Icons.tune_rounded), label: Text(tx(context, ScanTx.tabAdjust))),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (v) => _setMode(v.first),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    switch (_mode) {
      case _Mode.crop:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            children: [
              Text(tx(context, ScanTx.dragCorners),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rendering ? null : _autoDetect,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(tx(context, ScanTx.autoDetect)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _p.quad = fullPageQuad()),
                      icon: const Icon(Icons.fullscreen_rounded),
                      label: Text(tx(context, ScanTx.fullPage)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case _Mode.filter:
        return SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            itemCount: ScanFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final on = _p.filter == i;
              final scheme = Theme.of(context).colorScheme;
              final thumb = (_thumbs != null && i < _thumbs!.length) ? _thumbs![i] : null;
              return GestureDetector(
                onTap: () {
                  setState(() => _p.filter = i);
                  _render();
                },
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: on ? scheme.primary : scheme.outlineVariant, width: on ? 3 : 1),
                            color: scheme.surfaceContainerHighest,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: thumb == null
                              ? const Center(child: Icon(Icons.image_outlined))
                              : Image.memory(thumb, fit: BoxFit.cover, width: double.infinity, gaplessPlayback: true),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx(context, filterNames[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, fontWeight: on ? FontWeight.w800 : FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      case _Mode.adjust:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            children: [
              _slider(context, ScanTx.brightness, _p.brightness, (v) => _p.brightness = v),
              _slider(context, ScanTx.contrast, _p.contrast, (v) => _p.contrast = v),
              Row(
                children: [
                  IconButton(
                    tooltip: tx(context, ScanTx.rotateLeft),
                    onPressed: () => _rotate(-1),
                    icon: const Icon(Icons.rotate_left_rounded),
                  ),
                  IconButton(
                    tooltip: tx(context, ScanTx.rotateRight),
                    onPressed: () => _rotate(1),
                    icon: const Icon(Icons.rotate_right_rounded),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _p.brightness = 0;
                        _p.contrast = 0;
                        _p.rotation = 0;
                      });
                      _render();
                    },
                    child: Text(tx(context, ScanTx.reset)),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _slider(BuildContext context, LText label, double value, void Function(double) set) {
    return Row(
      children: [
        SizedBox(width: 92, child: Text(tx(context, label), style: const TextStyle(fontSize: 13))),
        Expanded(
          child: Slider(
            min: -100,
            max: 100,
            divisions: 40,
            value: value,
            label: value.round().toString(),
            onChanged: (v) => setState(() => set(v)),
            onChangeEnd: (_) => _render(),
          ),
        ),
      ],
    );
  }
}
