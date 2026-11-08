import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/ltext.dart';
import '../../../core/tools/notes_model.dart';
import '../../../widgets/page_body.dart';
import '../../../widgets/tr.dart';

const String _todoKey = 'tool_todos_v1';
const String _noteKey = 'tool_notes_v1';

/// Private notes and a to-do list, saved only on this phone.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<TodoItem> _todos = [];
  List<NoteItem> _notes = [];
  bool _loaded = false;
  final TextEditingController _newTodo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newTodo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _todos = decodeList<TodoItem>(p.getString(_todoKey), TodoItem.fromMap, kMaxTodos);
      _notes = decodeList<NoteItem>(p.getString(_noteKey), NoteItem.fromMap, kMaxNotes);
    } catch (_) {
      _todos = [];
      _notes = [];
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _saveTodos() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_todoKey, encodeList([for (final x in _todos) x.toMap()]));
    } catch (_) {/* keep working in memory */}
  }

  Future<void> _saveNotes() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_noteKey, encodeList([for (final n in _notes) n.toMap()]));
    } catch (_) {/* keep working in memory */}
  }

  void _addTodo() {
    final text = _newTodo.text.trim();
    if (text.isEmpty || _todos.length >= kMaxTodos) return;
    setState(() {
      _todos.insert(0, TodoItem(id: DateTime.now().microsecondsSinceEpoch.toString(), text: text));
      _newTodo.clear();
    });
    _saveTodos();
  }

  Future<void> _editNote(NoteItem? existing) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final body = TextEditingController(text: existing?.body ?? '');
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 80,
              decoration: InputDecoration(labelText: tr(ctx, t('Title', 'शीर्षक'))),
            ),
            TextField(
              controller: body,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: tr(ctx, t('Note', 'नोट')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (existing != null)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(tr(ctx, t('Delete', 'हटाएं'))),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, 'save'),
                  child: Text(tr(ctx, t('Save', 'सेव करें'))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final newTitle = title.text.trim();
    final newBody = body.text.trim();
    title.dispose();
    body.dispose();
    if (action == 'delete' && existing != null) {
      setState(() => _notes.removeWhere((n) => n.id == existing.id));
      await _saveNotes();
    } else if (action == 'save' && (newTitle.isNotEmpty || newBody.isNotEmpty)) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        if (existing != null) {
          existing.title = newTitle;
          existing.body = newBody;
          existing.updated = now;
        } else if (_notes.length < kMaxNotes) {
          _notes.add(NoteItem(id: now.toString(), title: newTitle, body: newBody, updated: now));
        }
        _notes.sort((a, b) => b.updated.compareTo(a.updated));
      });
      await _saveNotes();
    }
  }

  Widget _todoTab() {
    final open = _todos.where((x) => !x.done).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newTodo,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTodo(),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: tr(context, t('Add a task', 'काम जोड़ें')),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addTodo, icon: const Icon(Icons.add_rounded)),
            ],
          ),
        ),
        if (_todos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('$open ${tr(context, t('pending', 'बाकी'))}'),
                const Spacer(),
                TextButton(
                  onPressed: _todos.any((x) => x.done)
                      ? () {
                          setState(() => _todos.removeWhere((x) => x.done));
                          _saveTodos();
                        }
                      : null,
                  child: Text(tr(context, t('Clear done', 'पूरे हुए हटाएं'))),
                ),
              ],
            ),
          ),
        Expanded(
          child: _todos.isEmpty
              ? Center(child: Text(tr(context, t('No tasks yet', 'अभी कोई काम नहीं'))))
              : ListView.builder(
                  itemCount: _todos.length,
                  itemBuilder: (context, i) {
                    final item = _todos[i];
                    return CheckboxListTile(
                      value: item.done,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        item.text,
                        style: TextStyle(decoration: item.done ? TextDecoration.lineThrough : null),
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          setState(() => _todos.removeWhere((x) => x.id == item.id));
                          _saveTodos();
                        },
                      ),
                      onChanged: (v) {
                        setState(() => item.done = v ?? false);
                        _saveTodos();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _notesTab() {
    if (_notes.isEmpty) {
      return Center(child: Text(tr(context, t('No notes yet', 'अभी कोई नोट नहीं'))));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _notes.length,
      itemBuilder: (context, i) {
        final n = _notes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(n.title.isEmpty ? n.body : n.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: n.title.isEmpty || n.body.isEmpty
                ? null
                : Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _editNote(n),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return Scaffold(
            appBar: AppBar(
              title: Text(tr(context, t('Notes & To-do', 'नोट्स और टू-डू'))),
              bottom: TabBar(
                tabs: [
                  Tab(text: tr(context, t('To-do', 'टू-डू'))),
                  Tab(text: tr(context, t('Notes', 'नोट्स'))),
                ],
              ),
            ),
            floatingActionButton: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => controller.index == 1
                  ? FloatingActionButton.extended(
                      onPressed: () => _editNote(null),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr(context, t('New note', 'नया नोट'))),
                    )
                  : const SizedBox.shrink(),
            ),
            body: PageBody(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(children: [_todoTab(), _notesTab()]),
            ),
          );
        },
      ),
    );
  }
}
