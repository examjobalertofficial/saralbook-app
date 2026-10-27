import 'package:flutter/material.dart';

import '../../../core/pdfedit/edit_model.dart';
import '../../../core/pdfedit/edit_paint.dart';
import '../../../widgets/page_body.dart';
import '../files/file_ui.dart' show NoteBox, tx;
import 'pdf_editor_text.dart';

/// Re-order, rotate and delete the pages. Returns the new list on "Done".
class EditPagesScreen extends StatefulWidget {
  final List<EditPage> pages;
  const EditPagesScreen({super.key, required this.pages});

  @override
  State<EditPagesScreen> createState() => _EditPagesScreenState();
}

class _EditPagesScreenState extends State<EditPagesScreen> {
  late final List<EditPage> _list = List<EditPage>.of(widget.pages);
  bool _busy = false;

  void _move(int oldIndex, int newIndex) {
    setState(() => moveInList(_list, oldIndex, newIndex));
  }

  void _delete(int i) {
    if (_list.length < 2) return;
    setState(() => _list.removeAt(i));
  }

  Future<void> _rotate(int i) async {
    final page = _list[i];
    if (page.hasEdits) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx(context, EdTx.rotateBlocked))));
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final turned = await rotatePageClockwise(page);
      if (!mounted) return;
      final at = _list.indexWhere((p) => p.key == page.key);
      if (at >= 0) setState(() => _list[at] = turned);
    } catch (_) {
      // the page stays as it was
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, EdTx.pagesTitle), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(_list),
            child: Text(tx(context, EdTx.done)),
          ),
        ],
      ),
      body: PageBody(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: NoteBox(icon: Icons.drag_indicator_rounded, text: tx(context, EdTx.pagesHint)),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _list.length,
                onReorderItem: _move,
                itemBuilder: (context, i) {
                  final page = _list[i];
                  return Card(
                    key: ValueKey(page.key),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            height: 68,
                            child: Image.memory(
                              page.base,
                              fit: BoxFit.contain,
                              cacheWidth: 160,
                              gaplessPlayback: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('${tx(context, EdTx.page)} ${i + 1}', style: Theme.of(context).textTheme.titleSmall),
                          ),
                          IconButton(
                            tooltip: tx(context, EdTx.rotate),
                            icon: const Icon(Icons.rotate_right_rounded),
                            onPressed: _busy ? null : () => _rotate(i),
                          ),
                          IconButton(
                            tooltip: tx(context, EdTx.delete),
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: (_list.length < 2 || _busy) ? null : () => _delete(i),
                          ),
                          ReorderableDragStartListener(
                            index: i,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                        ],
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
