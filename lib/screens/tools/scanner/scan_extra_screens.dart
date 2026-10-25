import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;

import '../../../core/files/file_helpers.dart';
import '../../../core/scanner/scan_page.dart';
import '../../../core/scanner/scan_store.dart';
import '../../../widgets/page_body.dart';
import '../files/file_ui.dart';
import 'scan_text.dart';

/// Re-order the pages of a scan by dragging. Returns the new order on "Done".
class ScanReorderScreen extends StatefulWidget {
  final List<ScanPage> pages;
  const ScanReorderScreen({super.key, required this.pages});

  @override
  State<ScanReorderScreen> createState() => _ScanReorderScreenState();
}

class _ScanReorderScreenState extends State<ScanReorderScreen> {
  late final List<ScanPage> _list = List<ScanPage>.of(widget.pages);

  void _move(int oldIndex, int newIndex) {
    setState(() {
      final p = _list.removeAt(oldIndex);
      _list.insert(newIndex, p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, ScanTx.reorderTitle), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_list),
            child: Text(tx(context, ScanTx.done)),
          ),
        ],
      ),
      body: PageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NoteBox(icon: Icons.drag_indicator_rounded, text: tx(context, ScanTx.reorderHint)),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _list.length,
                onReorderItem: _move,
                itemBuilder: (context, i) {
                  final page = _list[i];
                  final thumb = page.thumb;
                  return Card(
                    key: ValueKey(page.key),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 64,
                        child: thumb == null
                            ? const Icon(Icons.image_outlined)
                            : Image.memory(thumb, fit: BoxFit.contain, gaplessPlayback: true),
                      ),
                      title: Text('${tx(context, ScanTx.pagesTitle)} ${i + 1}'),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Look at the finished PDF before sharing or saving it.
class ScanPdfPreviewScreen extends StatelessWidget {
  final OutputFile file;
  const ScanPdfPreviewScreen({super.key, required this.file});

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await saveCopy(file);
    } catch (_) {
      ok = false;
    }
    messenger.showSnackBar(SnackBar(content: Text(tx(context, ok ? Tx.saved : Tx.notSaved))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, ScanTx.previewTitle), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: tx(context, Tx.save),
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _save(context),
          ),
          IconButton(
            tooltip: tx(context, Tx.share),
            icon: const Icon(Icons.share_rounded),
            onPressed: () => shareOutputs([file]),
          ),
        ],
      ),
      body: PdfViewer.file(file.path, key: ValueKey(file.path)),
    );
  }
}

/// "My scans": the saved scans of the signed-in person. Tap one to open it.
class ScanLibraryScreen extends StatefulWidget {
  final ScanStore store;
  final String currentId;

  /// Called after a saved scan was deleted (the scanner clears itself if it
  /// was the one on screen).
  final void Function(String id) onDeleted;
  const ScanLibraryScreen({
    super.key,
    required this.store,
    required this.currentId,
    required this.onDeleted,
  });

  @override
  State<ScanLibraryScreen> createState() => _ScanLibraryScreenState();
}

class _ScanLibraryScreenState extends State<ScanLibraryScreen> {
  List<SavedScanInfo>? _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    List<SavedScanInfo> items;
    try {
      items = await widget.store.list();
    } catch (_) {
      items = const [];
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _delete(SavedScanInfo s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.name),
        content: Text(tx(ctx, ScanTx.deleteScanAsk)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tx(ctx, ScanTx.cancel))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tx(ctx, ScanTx.delete))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.store.delete(s.id);
    } catch (_) {/* shown again by the reload below */}
    widget.onDeleted(s.id);
    await _reload();
  }

  String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, ScanTx.myScans), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  NoteBox(icon: Icons.lock_outline_rounded, text: tx(context, ScanTx.libraryNote)),
                  const SizedBox(height: 14),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          tx(context, ScanTx.libraryEmpty),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  for (final s in items)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.of(context).pop(s.id),
                        leading: SizedBox(
                          width: 48,
                          height: 64,
                          child: s.cover == null
                              ? const Icon(Icons.description_outlined)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    s.cover!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 140,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.description_outlined),
                                  ),
                                ),
                        ),
                        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${tx(context, ScanTx.pagesCount(s.pages))} • ${formatBytes(s.bytes)}\n${_date(s.updated)}'
                          '${s.id == widget.currentId ? '\n${tx(context, ScanTx.openNow)}' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: tx(context, ScanTx.delete),
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _delete(s),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
