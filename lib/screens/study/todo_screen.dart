import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart';
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import 'personal_ui.dart';

enum _Filter { pending, done, all }

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: t('To-Do', 'टू-डू'), builder: (context, data) => _TodoList(data: data));
}

class _TodoList extends StatefulWidget {
  final PersonalData data;
  const _TodoList({required this.data});

  @override
  State<_TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<_TodoList> {
  _Filter _filter = _Filter.pending;

  static final LText _title = t('To-Do', 'टू-डू');
  static final LText _empty = t('Nothing here. Tap + to add a task.', 'यहां कुछ नहीं है। टास्क जोड़ने के लिए + दबाएं।');
  static final LText _deleted = t('Task deleted', 'टास्क हटाया गया');
  static final LText _overdue = t('Overdue', 'समय निकल गया');

  static final List<(int, LText)> _priorities = [
    (0, t('Low', 'कम')),
    (1, t('Medium', 'मध्यम')),
    (2, t('High', 'ज़्यादा')),
  ];

  Future<void> _edit(BuildContext context, Todo? existing) async {
    final controller = widget.data.todos;
    await showFormSheet<void>(context, (ctx) => _TodoForm(existing: existing, onSave: (todo) => controller.upsert(todo)));
  }

  String _priorityLabel(BuildContext context, int p) => tr(context, _priorities.firstWhere((e) => e.$1 == p).$2);

  @override
  Widget build(BuildContext context) {
    final controller = widget.data.todos;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!controller.loaded) return const Center(child: CircularProgressIndicator());
            final all = sortTodos(controller.items);
            final shown = switch (_filter) {
              _Filter.pending => all.where((e) => !e.done).toList(),
              _Filter.done => all.where((e) => e.done).toList(),
              _Filter.all => all,
            };
            return Column(
              children: [
                SyncProblemBanner(visible: controller.hasError),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ChipRow<_Filter>(
                      value: _filter,
                      options: [
                        (_Filter.pending, t('Pending', 'बाकी')),
                        (_Filter.done, t('Done', 'पूरे')),
                        (_Filter.all, t('All', 'सभी')),
                      ],
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? EmptyState(icon: Icons.checklist_rounded, message: _empty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final todo = shown[i];
                            final overdue = isOverdue(todo.dueAt, todo.done, now);
                            return Dismissible(
                              key: ValueKey(todo.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                              ),
                              onDismissed: (_) {
                                controller.remove(todo.id);
                                showUndo(context, _deleted, () => controller.upsert(todo));
                              },
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                color: scheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: scheme.outlineVariant),
                                ),
                                child: ListTile(
                                  onTap: () => _edit(context, todo),
                                  leading: Checkbox(
                                    value: todo.done,
                                    onChanged: (v) => controller.upsert(todo.copyWith(done: v ?? false)),
                                  ),
                                  title: Text(
                                    todo.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      decoration: todo.done ? TextDecoration.lineThrough : null,
                                      color: todo.done ? scheme.onSurfaceVariant : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Wrap(
                                    spacing: 10,
                                    children: [
                                      if (todo.dueAt != null)
                                        Text(
                                          overdue
                                              ? '${tr(context, _overdue)}: ${fmtDateMs(todo.dueAt!)}'
                                              : fmtDateMs(todo.dueAt!),
                                          style: TextStyle(color: overdue ? scheme.error : scheme.onSurfaceVariant),
                                        ),
                                      Text(
                                        _priorityLabel(context, todo.priority),
                                        style: TextStyle(
                                          color: todo.priority == 2 ? scheme.error : scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodoForm extends StatefulWidget {
  final Todo? existing;
  final ValueChanged<Todo> onSave;
  const _TodoForm({required this.existing, required this.onSave});

  @override
  State<_TodoForm> createState() => _TodoFormState();
}

class _TodoFormState extends State<_TodoForm> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late int _priority = widget.existing?.priority ?? 1;
  late int? _due = widget.existing?.dueAt;

  static final LText _newTitle = t('New task', 'नया टास्क');
  static final LText _editTitle = t('Edit task', 'टास्क बदलें');
  static final LText _hint = t('What do you need to do?', 'आपको क्या करना है?');
  static final LText _priorityLabel = t('Priority', 'प्राथमिकता');
  static final LText _save = t('Save', 'सेव करें');

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final e = widget.existing;
    widget.onSave(
      e == null
          ? Todo.create(title: title, priority: _priority, dueAt: _due)
          : e.copyWith(title: title, priority: _priority, dueAt: _due, clearDue: _due == null),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, widget.existing == null ? _newTitle : _editTitle),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: tr(context, _hint), border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Text(tr(context, _priorityLabel), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ChipRow<int>(
          value: _priority,
          options: _TodoListState._priorities,
          onChanged: (v) => setState(() => _priority = v),
        ),
        const SizedBox(height: 14),
        DueDateField(value: _due, onChanged: (v) => setState(() => _due = v)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _title.text.trim().isEmpty ? null : _submit,
            child: Text(tr(context, _save)),
          ),
        ),
      ],
    );
  }
}
