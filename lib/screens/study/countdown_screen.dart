import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/personal/logic.dart';
import '../../core/personal/models.dart';
import '../../core/personal/personal_data.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import 'personal_ui.dart';

final LText _title = t('Exam Countdown', 'परीक्षा काउंटडाउन');

class CountdownScreen extends StatelessWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Countdown(data: data));
}

class _Countdown extends StatefulWidget {
  final PersonalData data;
  const _Countdown({required this.data});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  static final LText _empty = t('Add your exam date to see the countdown.', 'काउंटडाउन देखने के लिए अपनी परीक्षा की तारीख जोड़ें।');
  static final LText _passed = t('Exam date has passed', 'परीक्षा की तारीख निकल चुकी है');
  static final LText _deleted = t('Exam deleted', 'परीक्षा हटाई गई');

  @override
  void initState() {
    super.initState();
    // refresh the numbers every 20 seconds
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _edit(BuildContext context, Exam? existing) {
    showFormSheet<void>(context, (ctx) => _ExamForm(existing: existing, onSave: widget.data.exams.upsert));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.data.exams;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, null), child: const Icon(Icons.add_rounded)),
      body: PageBody(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (!controller.loaded) return const Center(child: CircularProgressIndicator());
            final exams = sortExams(controller.items, _now);
            if (exams.isEmpty) {
              return Column(children: [
                SyncProblemBanner(visible: controller.hasError),
                Expanded(child: EmptyState(icon: Icons.event_available_outlined, message: _empty)),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: exams.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return SyncProblemBanner(visible: controller.hasError);
                final e = exams[i - 1];
                final at = DateTime.fromMillisecondsSinceEpoch(e.at);
                final c = countdownTo(at, _now);
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(18)),
                    child: Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    controller.remove(e.id);
                    showUndo(context, _deleted, () => controller.upsert(e));
                  },
                  child: GestureDetector(
                    onTap: () => _edit(context, e),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: c.passed ? scheme.surfaceContainerHighest : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.passed ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${fmtDate(at)}  •  ${fmtTime(at)}',
                            style: TextStyle(color: c.passed ? scheme.onSurfaceVariant : scheme.onPrimaryContainer),
                          ),
                          const SizedBox(height: 12),
                          if (c.passed)
                            Text(tr(context, _passed), style: TextStyle(color: scheme.onSurfaceVariant))
                          else
                            Row(
                              children: [
                                _Unit(value: c.days, label: tr(context, t('days', 'दिन')), color: scheme.onPrimaryContainer),
                                const SizedBox(width: 18),
                                _Unit(value: c.hours, label: tr(context, t('hours', 'घंटे')), color: scheme.onPrimaryContainer),
                                const SizedBox(width: 18),
                                _Unit(value: c.minutes, label: tr(context, t('min', 'मिनट')), color: scheme.onPrimaryContainer),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _Unit({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _ExamForm extends StatefulWidget {
  final Exam? existing;
  final ValueChanged<Exam> onSave;
  const _ExamForm({required this.existing, required this.onSave});

  @override
  State<_ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends State<_ExamForm> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late DateTime _at = widget.existing != null
      ? DateTime.fromMillisecondsSinceEpoch(widget.existing!.at)
      : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 30, 10);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final e = widget.existing;
    final at = _at.millisecondsSinceEpoch;
    widget.onSave(e == null ? Exam.create(name: name, at: at) : e.copyWith(name: name, at: at));
    Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _at.isBefore(now) ? now : _at,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _at = DateTime(picked.year, picked.month, picked.day, _at.hour, _at.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _at.hour, minute: _at.minute));
    if (picked != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, widget.existing == null ? t('Add exam', 'परीक्षा जोड़ें') : t('Edit exam', 'परीक्षा बदलें')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: tr(context, t('Exam name, e.g. SSC CGL Tier 1', 'परीक्षा का नाम, जैसे SSC CGL Tier 1')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(fmtDate(_at)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(fmtTime(_at)),
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
