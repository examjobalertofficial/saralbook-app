import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart';
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import 'personal_ui.dart';

final LText _planner = t('Study Planner', 'स्टडी प्लानर');

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _planner, builder: (context, data) => _Planner(data: data));
}

class _Planner extends StatelessWidget {
  final PersonalData data;
  const _Planner({required this.data});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, _planner), style: const TextStyle(fontWeight: FontWeight.w700)),
          bottom: TabBar(
            tabs: [
              Tab(text: tr(context, t('Tasks', 'टास्क'))),
              Tab(text: tr(context, t('Subjects', 'विषय'))),
              Tab(text: tr(context, t('Goals', 'लक्ष्य'))),
            ],
          ),
        ),
        body: PageBody(
          child: ListenableBuilder(
            listenable: Listenable.merge([data.subjects, data.studyTasks, data.goals, data.sessions]),
            builder: (context, _) {
              if (!data.subjects.loaded || !data.studyTasks.loaded || !data.goals.loaded) {
                return const Center(child: CircularProgressIndicator());
              }
              return TabBarView(
                children: [
                  _TasksTab(data: data),
                  _SubjectsTab(data: data),
                  _GoalsTab(data: data),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Widget _addButton(BuildContext context, LText label, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr(context, label)),
        ),
      ),
    );

BoxDecoration _cardDecoration(ColorScheme scheme) => BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outlineVariant),
    );

// ============================ Tasks ============================

class _TasksTab extends StatelessWidget {
  final PersonalData data;
  const _TasksTab({required this.data});

  static final LText _add = t('Add study task', 'स्टडी टास्क जोड़ें');
  static final LText _empty = t('No study tasks yet.', 'अभी कोई स्टडी टास्क नहीं।');
  static final LText _deleted = t('Task deleted', 'टास्क हटाया गया');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = sortTasks(data.studyTasks.items);
    final subjects = data.subjects.items;
    return Column(
      children: [
        SyncProblemBanner(visible: data.studyTasks.hasError),
        _addButton(context, _add, () => showFormSheet<void>(
              context,
              (ctx) => _TaskForm(subjects: subjects, existing: null, onSave: data.studyTasks.upsert),
            )),
        Expanded(
          child: tasks.isEmpty
              ? EmptyState(icon: Icons.task_alt_rounded, message: _empty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    final subject = subjects.where((s) => s.id == task.subjectId);
                    final overdue = isOverdue(task.dueAt, task.done, DateTime.now());
                    return Dismissible(
                      key: ValueKey(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
                        child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                      ),
                      onDismissed: (_) {
                        data.studyTasks.remove(task.id);
                        showUndo(context, _deleted, () => data.studyTasks.upsert(task));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: _cardDecoration(scheme),
                        child: ListTile(
                          onTap: () => showFormSheet<void>(
                            context,
                            (ctx) => _TaskForm(subjects: subjects, existing: task, onSave: data.studyTasks.upsert),
                          ),
                          leading: Checkbox(
                            value: task.done,
                            onChanged: (v) => data.studyTasks.upsert(task.copyWith(done: v ?? false)),
                          ),
                          title: Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              decoration: task.done ? TextDecoration.lineThrough : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (subject.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 5, backgroundColor: subjectColor(subject.first.colorIndex)),
                                    const SizedBox(width: 6),
                                    Text(subject.first.name),
                                  ],
                                ),
                              if (task.dueAt != null)
                                Text(
                                  fmtDateMs(task.dueAt!),
                                  style: TextStyle(color: overdue ? scheme.error : scheme.onSurfaceVariant),
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
  }
}

class _TaskForm extends StatefulWidget {
  final List<Subject> subjects;
  final StudyTask? existing;
  final ValueChanged<StudyTask> onSave;
  const _TaskForm({required this.subjects, required this.existing, required this.onSave});

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late String _subjectId = widget.existing?.subjectId ?? '';
  late int? _due = widget.existing?.dueAt;

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
          ? StudyTask.create(title: title, subjectId: _subjectId, dueAt: _due)
          : e.copyWith(title: title, subjectId: _subjectId, dueAt: _due, clearDue: _due == null),
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
          tr(context, widget.existing == null ? t('New study task', 'नया स्टडी टास्क') : t('Edit task', 'टास्क बदलें')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          autofocus: true,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: tr(context, t('e.g. Finish Algebra chapter 3', 'जैसे बीजगणित अध्याय 3 पूरा करें')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Text(tr(context, t('Subject', 'विषय')), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ChipRow<String>(
          value: _subjectId,
          options: [
            ('', t('None', 'कोई नहीं')),
            for (final s in widget.subjects) (s.id, LText({'en': s.name, 'hi': s.name})),
          ],
          onChanged: (v) => setState(() => _subjectId = v),
        ),
        const SizedBox(height: 14),
        DueDateField(value: _due, onChanged: (v) => setState(() => _due = v)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _title.text.trim().isEmpty ? null : _submit,
            child: Text(tr(context, t('Save', 'सेव करें'))),
          ),
        ),
      ],
    );
  }
}

// ============================ Subjects ============================

class _SubjectsTab extends StatelessWidget {
  final PersonalData data;
  const _SubjectsTab({required this.data});

  static final LText _add = t('Add subject', 'विषय जोड़ें');
  static final LText _empty = t('Add your subjects, e.g. Maths, Reasoning, GK.', 'अपने विषय जोड़ें, जैसे गणित, रीज़निंग, GK।');
  static final LText _deleteQ = t('Delete this subject? Its tasks and study time are kept.', 'यह विषय हटाएं? उसके टास्क और पढ़ाई का समय बने रहेंगे।');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subjects = List<Subject>.of(data.subjects.items)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return Column(
      children: [
        SyncProblemBanner(visible: data.subjects.hasError),
        _addButton(context, _add, () => showFormSheet<void>(context, (ctx) => _SubjectForm(onSave: data.subjects.upsert))),
        Expanded(
          child: subjects.isEmpty
              ? EmptyState(icon: Icons.menu_book_outlined, message: _empty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: subjects.length,
                  itemBuilder: (context, i) {
                    final s = subjects[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: _cardDecoration(scheme),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: subjectColor(s.colorIndex), radius: 14),
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(tr(ctx, _deleteQ)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: Text(tr(ctx, t('Cancel', 'रद्द करें'))),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: Text(tr(ctx, t('Delete', 'हटाएं'))),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true) data.subjects.remove(s.id);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SubjectForm extends StatefulWidget {
  final ValueChanged<Subject> onSave;
  const _SubjectForm({required this.onSave});

  @override
  State<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<_SubjectForm> {
  final TextEditingController _name = TextEditingController();
  int _color = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.onSave(Subject.create(name: name, colorIndex: _color));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, t('New subject', 'नया विषय')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: tr(context, t('Subject name', 'विषय का नाम')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < subjectColors.length; i++)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _color = i),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: subjectColors[i],
                  child: _color == i ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _name.text.trim().isEmpty ? null : _submit,
            child: Text(tr(context, t('Save', 'सेव करें'))),
          ),
        ),
      ],
    );
  }
}

// ============================ Goals ============================

LText periodLabel(GoalPeriod p) => switch (p) {
      GoalPeriod.daily => t('Daily', 'रोज़ाना'),
      GoalPeriod.weekly => t('Weekly', 'साप्ताहिक'),
      GoalPeriod.monthly => t('Monthly', 'मासिक'),
    };

class _GoalsTab extends StatelessWidget {
  final PersonalData data;
  const _GoalsTab({required this.data});

  static final LText _add = t('Add study goal', 'स्टडी लक्ष्य जोड़ें');
  static final LText _empty = t('Set a goal, e.g. 10 hours of study every week.', 'लक्ष्य रखें, जैसे हर हफ़्ते 10 घंटे पढ़ाई।');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final goals = List<Goal>.of(data.goals.items)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final now = DateTime.now();
    return Column(
      children: [
        SyncProblemBanner(visible: data.goals.hasError),
        _addButton(
          context,
          _add,
          () => showFormSheet<void>(context, (ctx) => _GoalForm(subjects: data.subjects.items, onSave: data.goals.upsert)),
        ),
        Expanded(
          child: goals.isEmpty
              ? EmptyState(icon: Icons.flag_outlined, message: _empty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: goals.length,
                  itemBuilder: (context, i) {
                    final g = goals[i];
                    final p = goalProgress(g, data.sessions.items, now);
                    final subject = subjectNameOf(data.subjects.items, g.subjectId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                      decoration: _cardDecoration(scheme),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  g.title.isEmpty ? '${tr(context, periodLabel(g.period))} ${formatMinutes(g.targetMinutes)}' : g.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => data.goals.remove(g.id),
                              ),
                            ],
                          ),
                          Text(
                            [
                              tr(context, periodLabel(g.period)),
                              if (subject.isNotEmpty) subject,
                              '${formatMinutes(p.minutes)} / ${formatMinutes(g.targetMinutes)}',
                            ].join('  •  '),
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: LinearProgressIndicator(value: p.fraction, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GoalForm extends StatefulWidget {
  final List<Subject> subjects;
  final ValueChanged<Goal> onSave;
  const _GoalForm({required this.subjects, required this.onSave});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _hours = TextEditingController(text: '10');
  GoalPeriod _period = GoalPeriod.weekly;
  String _subjectId = '';

  @override
  void dispose() {
    _title.dispose();
    _hours.dispose();
    super.dispose();
  }

  int? get _minutes {
    final h = double.tryParse(_hours.text.trim());
    if (h == null || h <= 0 || h > 1000) return null;
    return (h * 60).round();
  }

  void _submit() {
    final m = _minutes;
    if (m == null) return;
    widget.onSave(Goal.create(
      title: _title.text.trim(),
      period: _period,
      targetMinutes: m,
      subjectId: _subjectId,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, t('New study goal', 'नया स्टडी लक्ष्य')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _title,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: tr(context, t('Goal name (optional)', 'लक्ष्य का नाम (वैकल्पिक)')),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ChipRow<GoalPeriod>(
          value: _period,
          options: [for (final p in GoalPeriod.values) (p, periodLabel(p))],
          onChanged: (v) => setState(() => _period = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _hours,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr(context, t('Study time target', 'पढ़ाई का लक्ष्य')),
            suffixText: tr(context, t('hours', 'घंटे')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text(tr(context, t('Subject', 'विषय')), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ChipRow<String>(
          value: _subjectId,
          options: [
            ('', t('All subjects', 'सभी विषय')),
            for (final s in widget.subjects) (s.id, LText({'en': s.name, 'hi': s.name})),
          ],
          onChanged: (v) => setState(() => _subjectId = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _minutes == null ? null : _submit,
            child: Text(tr(context, t('Save', 'सेव करें'))),
          ),
        ),
      ],
    );
  }
}
