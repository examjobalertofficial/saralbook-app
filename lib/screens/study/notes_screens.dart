import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart';
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import 'personal_ui.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: t('Notes', 'नोट्स'), builder: (context, data) => _NotesList(data: data));
}

class _NotesList extends StatefulWidget {
  final PersonalData data;
  const _NotesList({required this.data});

  @override
  State<_NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<_NotesList> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _tag;

  static final LText _title = t('Notes', 'नोट्स');
  static final LText _searchHint = t('Search notes', 'नोट्स खोजें');
  static final LText _empty = t('No notes yet. Tap + to write your first note.', 'अभी कोई नोट नहीं। पहला नोट लिखने के लिए + दबाएं।');
  static final LText _noMatch = t('No notes match your search.', 'आपकी खोज से कोई नोट नहीं मिला।');
  static final LText _untitled = t('Untitled', 'बिना शीर्षक');
  static final LText _deleted = t('Note deleted', 'नोट हटाया गया');
  static final LText _all = t('All', 'सभी');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(BuildContext context, String? id) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(data: widget.data, noteId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.data.notes;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(context, null),
        child: const Icon(Icons.add_rounded),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!controller.loaded) return const Center(child: CircularProgressIndicator());
            final tags = allTags(controller.items);
            // forget a tag that no longer exists
            final tag = (_tag != null && tags.contains(_tag)) ? _tag : null;
            final shown = filterNotes(controller.items, query: _query, tag: tag);
            return Column(
              children: [
                SyncProblemBanner(visible: controller.hasError),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: tr(context, _searchHint),
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (tags.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tr(context, _all)),
                            selected: tag == null,
                            onSelected: (_) => setState(() => _tag = null),
                          ),
                        ),
                        for (final t in tags)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('#$t'),
                              selected: tag == t,
                              onSelected: (_) => setState(() => _tag = t),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: shown.isEmpty
                      ? EmptyState(
                          icon: Icons.sticky_note_2_outlined,
                          message: controller.items.isEmpty ? _empty : _noMatch,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final n = shown[i];
                            return Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                                child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                              ),
                              onDismissed: (_) {
                                controller.remove(n.id);
                                showUndo(context, _deleted, () => controller.upsert(n));
                              },
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 10),
                                color: scheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: scheme.outlineVariant),
                                ),
                                child: ListTile(
                                  onTap: () => _open(context, n.id),
                                  title: Text(
                                    n.title.trim().isEmpty ? tr(context, _untitled) : n.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (n.body.trim().isNotEmpty)
                                        Text(n.body.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          fmtDateMs(n.updatedAt),
                                          if (n.tags.isNotEmpty) n.tags.map((e) => '#$e').join(' '),
                                        ].join('  •  '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
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

/// Write / edit one note. It saves by itself when you go back.
class NoteEditorScreen extends StatefulWidget {
  final PersonalData data;
  final String? noteId;
  const NoteEditorScreen({super.key, required this.data, this.noteId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final Note? _base = widget.noteId == null ? null : widget.data.notes.byId(widget.noteId!);
  late final String _id = _base?.id ?? newNoteId();
  late final TextEditingController _title = TextEditingController(text: _base?.title ?? '');
  late final TextEditingController _body = TextEditingController(text: _base?.body ?? '');
  late final TextEditingController _tags = TextEditingController(text: _base?.tags.join(', ') ?? '');
  bool _skipSave = false;
  bool _saved = false;

  static final LText _editorTitle = t('Note', 'नोट');
  static final LText _titleHint = t('Title', 'शीर्षक');
  static final LText _bodyHint = t('Write here...', 'यहां लिखें...');
  static final LText _tagsHint = t('Tags (comma separated), e.g. maths, gs', 'टैग (कॉमा से अलग), जैसे maths, gs');
  static final LText _copyNote = t(
    'This note was changed on another phone, so your version was saved as a copy.',
    'यह नोट दूसरे फ़ोन पर बदला गया था, इसलिए आपका वर्ज़न कॉपी के रूप में सेव हुआ।',
  );
  static final LText _deleteQ = t('Delete this note?', 'यह नोट हटाएं?');
  static final LText _delete = t('Delete', 'हटाएं');
  static final LText _cancel = t('Cancel', 'रद्द करें');
  static final LText _copySuffix = t('(copy)', '(कॉपी)');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  /// Saves without ever overwriting a change made on another phone.
  void _save(BuildContext context) {
    if (_saved || _skipSave) return;
    _saved = true;
    final now = nowMs();
    final draft = Note(
      id: _id,
      title: _title.text.trim(),
      body: _body.text.trim(),
      tags: parseTags(_tags.text),
      createdAt: _base?.createdAt ?? now,
      updatedAt: now,
    );
    final action = resolveNoteSave(
      base: _base,
      current: widget.data.notes.byId(_id),
      draft: draft,
    );
    final notes = widget.data.notes;
    switch (action) {
      case NoteSaveAction.nothing:
        break;
      case NoteSaveAction.create:
      case NoteSaveAction.update:
        notes.upsert(draft);
      case NoteSaveAction.saveAsCopy:
        final lang = Localizations.localeOf(context).languageCode;
        notes.upsert(Note.create(
          title: '${draft.title} ${_copySuffix.of(lang)}'.trim(),
          body: draft.body,
          tags: draft.tags,
        ));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_copyNote.of(lang))));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final base = _base;
    final lang = Localizations.localeOf(context).languageCode;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, _deleteQ)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, _cancel))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr(ctx, _delete))),
        ],
      ),
    );
    if (yes != true) return;
    _skipSave = true;
    if (base != null) {
      widget.data.notes.remove(base.id);
      final label = t('Undo', 'वापस लाएं').of(lang);
      messenger.showSnackBar(
        SnackBar(
          content: Text(t('Note deleted', 'नोट हटाया गया').of(lang)),
          action: SnackBarAction(label: label, onPressed: () => widget.data.notes.upsert(base)),
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _save(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, _editorTitle), style: const TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            if (_base != null)
              IconButton(
                tooltip: tr(context, _delete),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _confirmDelete(context),
              ),
            IconButton(
              icon: const Icon(Icons.check_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        body: PageBody(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: tr(context, _titleHint),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _body,
                    maxLines: null,
                    expands: true,
                    maxLength: 20000,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
                    decoration: InputDecoration(hintText: tr(context, _bodyHint), border: InputBorder.none),
                  ),
                ),
                TextField(
                  controller: _tags,
                  decoration: InputDecoration(
                    hintText: tr(context, _tagsHint),
                    prefixIcon: const Icon(Icons.sell_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A fresh id for a note (kept in one place so tests can swap it later).
String newNoteId() => Note.create().id;
