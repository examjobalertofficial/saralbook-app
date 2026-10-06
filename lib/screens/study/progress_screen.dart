import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart';
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import 'personal_ui.dart';
import 'planner_screen.dart' show periodLabel;

final LText _title = t('Study Progress', 'पढ़ाई की प्रगति');

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Progress(data: data));
}

class _Progress extends StatefulWidget {
  final PersonalData data;
  const _Progress({required this.data});

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  ProgressPeriod _period = ProgressPeriod.week;

  static final LText _logTime = t('Log study time', 'पढ़ाई का समय जोड़ें');
  static final LText _studyTime = t('Study time', 'पढ़ाई का समय');
  static final LText _tasksDone = t('Tasks completed', 'पूरे हुए टास्क');
  static final LText _perDay = t('Per day', 'रोज़ का हिसाब');
  static final LText _bySubject = t('By subject', 'विषय के अनुसार');
  static final LText _goals = t('Goals', 'लक्ष्य');
  static final LText _recent = t('Recent study sessions', 'हाल के स्टडी सेशन');
  static final LText _noSubject = t('No subject', 'कोई विषय नहीं');
  static final LText _noData = t('No study time logged in this period yet.', 'इस अवधि में अभी कोई पढ़ाई दर्ज नहीं है।');
  static final LText _deleted = t('Session deleted', 'सेशन हटाया गया');

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([data.sessions, data.subjects, data.studyTasks, data.todos, data.goals]),
          builder: (context, _) {
            final now = DateTime.now();
            final range = rangeFor(_period, now);
            final sessions = data.sessions.items;
            final subjects = data.subjects.items;
            final total = minutesInRange(sessions, range);
            final done = completedInRange(tasks: data.studyTasks.items, todos: data.todos.items, range: range);
            final bySubject = minutesBySubject(sessions, range);
            final daily = dailyMinutes(sessions, range);
            final recent = List<StudySession>.of(sessions)..sort((a, b) => b.startedAt.compareTo(a.startedAt));
            final goals = data.goals.items;

            Widget card(Widget child) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: child,
                );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                SyncProblemBanner(visible: data.sessions.hasError),
                ChipRow<ProgressPeriod>(
                  value: _period,
                  options: [
                    (ProgressPeriod.today, t('Today', 'आज')),
                    (ProgressPeriod.week, t('This week', 'यह सप्ताह')),
                    (ProgressPeriod.month, t('This month', 'यह महीना')),
                  ],
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: tr(context, _studyTime), value: formatMinutes(total), color: scheme.primaryContainer, onColor: scheme.onPrimaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stat(label: tr(context, _tasksDone), value: '$done', color: scheme.tertiaryContainer, onColor: scheme.onTertiaryContainer),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => showFormSheet<void>(
                      context,
                      (ctx) => _LogSessionForm(subjects: subjects, onSave: data.sessions.upsert),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr(context, _logTime)),
                  ),
                ),
                const SizedBox(height: 14),
                if (_period != ProgressPeriod.today)
                  card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, _perDay), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _BarChart(values: [for (final d in daily) d.minutes], days: [for (final d in daily) d.day.day]),
                    ],
                  )),
                card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context, _bySubject), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (bySubject.isEmpty)
                      Text(tr(context, _noData), style: TextStyle(color: scheme.onSurfaceVariant))
                    else
                      for (final e in bySubject)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key.isEmpty || subjectNameOf(subjects, e.key).isEmpty
                                          ? tr(context, _noSubject)
                                          : subjectNameOf(subjects, e.key),
                                    ),
                                  ),
                                  Text(formatMinutes(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: total == 0 ? 0 : e.value / total,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                                color: subjectColor(
                                  subjects.where((s) => s.id == e.key).isEmpty ? 7 : subjects.firstWhere((s) => s.id == e.key).colorIndex,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                )),
                if (goals.isNotEmpty)
                  card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, _goals), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      for (final g in goals)
                        Builder(builder: (context) {
                          final p = goalProgress(g, sessions, now);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g.title.isEmpty ? '${tr(context, periodLabel(g.period))} ${formatMinutes(g.targetMinutes)}' : g.title,
                                      ),
                                    ),
                                    Text('${formatMinutes(p.minutes)} / ${formatMinutes(g.targetMinutes)}'),
                                    if (p.reached) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.check_circle_rounded, size: 18)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(value: p.fraction, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                              ],
                            ),
                          );
                        }),
                    ],
                  )),
                if (recent.isNotEmpty)
                  card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(context, _recent), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      for (final s in recent.take(5))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${formatMinutes(s.minutes)}  •  ${subjectNameOf(subjects, s.subjectId).isEmpty ? tr(context, _noSubject) : subjectNameOf(subjects, s.subjectId)}',
                          ),
                          subtitle: Text(fmtDateMs(s.startedAt)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () {
                              data.sessions.remove(s.id);
                              showUndo(context, _deleted, () => data.sessions.upsert(s));
                            },
                          ),
                        ),
                    ],
                  )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color onColor;
  const _Stat({required this.label, required this.value, required this.color, required this.onColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: onColor)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: onColor)),
          ),
        ],
      ),
    );
  }
}

/// Light-weight bar chart (no chart library needed).
class _BarChart extends StatelessWidget {
  final List<int> values;
  final List<int> days;
  const _BarChart({required this.values, required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.fold<int>(0, (a, b) => b > a ? b : a);
    final many = values.length > 10;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: many ? 1 : 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: maxV == 0 ? 0.02 : (values[i] / maxV).clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: values[i] == 0 ? scheme.surfaceContainerHighest : scheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: (!many || days[i] == 1 || days[i] % 5 == 0)
                          ? FittedBox(child: Text('${days[i]}', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogSessionForm extends StatefulWidget {
  final List<Subject> subjects;
  final ValueChanged<StudySession> onSave;
  const _LogSessionForm({required this.subjects, required this.onSave});

  @override
  State<_LogSessionForm> createState() => _LogSessionFormState();
}

class _LogSessionFormState extends State<_LogSessionForm> {
  final TextEditingController _minutes = TextEditingController(text: '30');
  String _subjectId = '';
  DateTime _date = dayOf(DateTime.now());

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  int? get _value {
    final v = int.tryParse(_minutes.text.trim());
    return (v == null || v < 1 || v > 1440) ? null : v;
  }

  void _submit() {
    final m = _value;
    if (m == null) return;
    // noon of the chosen day, so the session belongs to that day in every time zone
    final startedAt = DateTime(_date.year, _date.month, _date.day, 12).millisecondsSinceEpoch;
    widget.onSave(StudySession.create(subjectId: _subjectId, minutes: m, startedAt: startedAt));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, t('Log study time', 'पढ़ाई का समय जोड़ें')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _minutes,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr(context, t('Time studied', 'पढ़ाई का समय')),
            suffixText: tr(context, t('minutes', 'मिनट')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(now.year - 1),
              lastDate: now,
            );
            if (picked != null) setState(() => _date = dayOf(picked));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: tr(context, t('Date', 'तारीख')),
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(fmtDateMs(_date.millisecondsSinceEpoch)),
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _value == null ? null : _submit, child: Text(tr(context, t('Save', 'सेव करें')))),
        ),
      ],
    );
  }
}
