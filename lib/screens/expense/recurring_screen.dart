import 'package:flutter/material.dart';

import '../../core/expense/logic.dart';
import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/expense/recurring_engine.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/personal_data.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'expense_ui.dart';

final LText _title = t('Repeating transactions', 'दोहराव वाले लेन-देन');

LText frequencyLabel(Frequency f) => switch (f) {
      Frequency.daily => t('Daily', 'रोज़'),
      Frequency.weekly => t('Weekly', 'साप्ताहिक'),
      Frequency.monthly => t('Monthly', 'मासिक'),
      Frequency.yearly => t('Yearly', 'वार्षिक'),
    };

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Recurring(data: data));
}

class _Recurring extends StatelessWidget {
  final PersonalData data;
  const _Recurring({required this.data});

  static final LText _add = t('Add repeating', 'दोहराव जोड़ें');
  static final LText _empty = t(
    'Salary, rent, EMI, subscriptions... Add them once and they are recorded automatically on their dates.',
    'वेतन, किराया, EMI, सब्सक्रिप्शन... एक बार जोड़ें, वे अपनी तारीख पर अपने आप दर्ज हो जाएंगे।',
  );
  static final LText _stopQ = t(
    'Stop this repeating transaction? Transactions already recorded stay.',
    'यह दोहराव बंद करें? जो लेन-देन दर्ज हो चुके हैं वे बने रहेंगे।',
  );
  static final LText _paused = t('Paused', 'रुका हुआ');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFormSheet<void>(context, (ctx) => _RuleForm(data: data, existing: null)),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, _add)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: Listenable.merge([data.recurring, data.expenseCategories]),
          builder: (context, _) {
            if (!data.recurring.loaded) return const Center(child: CircularProgressIndicator());
            final rules = List<RecurringRule>.of(data.recurring.items)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            if (rules.isEmpty) return EmptyState(icon: Icons.repeat_rounded, message: _empty);
            final today = DateTime.now();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: rules.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return SyncProblemBanner(visible: data.recurring.hasError);
                final r = rules[i - 1];
                final cat = categoryFor(data, r.categoryId);
                final income = r.type == TxnType.income;
                final next = nextOccurrence(r, today);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: ListTile(
                    onTap: () => showFormSheet<void>(context, (ctx) => _RuleForm(data: data, existing: r)),
                    leading: CircleAvatar(
                      backgroundColor: categoryColor(cat).withAlpha(36),
                      child: Icon(categoryIcon(cat.iconKey), color: categoryColor(cat)),
                    ),
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${income ? '+' : '-'}${formatInr(r.amountMinor)}  •  ${tr(context, frequencyLabel(r.frequency))}\n'
                      '${r.active ? '${tr(context, t('Next', 'अगला'))}: ${fmtDate(next)}' : tr(context, _paused)}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: r.active,
                          onChanged: (on) {
                            // resuming skips what was missed while it was paused
                            data.recurring.upsert(on ? resumeRule(r, DateTime.now()) : r.copyWith(active: false));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop_circle_outlined),
                          tooltip: tr(context, t('Stop', 'बंद करें')),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(tr(ctx, _stopQ)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, t('Cancel', 'रद्द करें')))),
                                  FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr(ctx, t('Stop', 'बंद करें')))),
                                ],
                              ),
                            );
                            if (yes == true) data.recurring.remove(r.id);
                          },
                        ),
                      ],
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

class _RuleForm extends StatefulWidget {
  final PersonalData data;
  final RecurringRule? existing;
  const _RuleForm({required this.data, required this.existing});

  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  late TxnType _type = widget.existing?.type ?? TxnType.expense;
  late String _categoryId = widget.existing?.categoryId ?? 'bills';
  late Frequency _frequency = widget.existing?.frequency ?? Frequency.monthly;
  late DateTime _start = widget.existing == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(widget.existing!.startDate);
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null ? '' : minorToPlain(widget.existing!.amountMinor),
  );

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  int? get _minor => parseMinor(_amount.text);
  bool get _valid => _title.text.trim().isNotEmpty && _minor != null;

  void _submit() {
    final minor = _minor;
    if (!_valid || minor == null) return;
    final e = widget.existing;
    final rule = e == null
        ? RecurringRule.create(
            title: _title.text.trim(),
            type: _type,
            amountMinor: minor,
            categoryId: _categoryId,
            frequency: _frequency,
            startDate: _start,
          )
        : e.copyWith(
            title: _title.text.trim(),
            type: _type,
            amountMinor: minor,
            categoryId: _categoryId,
            frequency: _frequency,
            startDate: _start,
          );
    final data = widget.data;
    data.recurring.upsert(rule);
    Navigator.of(context).pop();
    // a rule that starts today or earlier creates its first transaction now
    if (e == null) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        runRecurringNow(data);
      });
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _start = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, widget.existing == null ? t('New repeating transaction', 'नया दोहराव') : t('Edit repeating transaction', 'दोहराव बदलें')),
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          autofocus: widget.existing == null,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: tr(context, t('Name, e.g. Rent, Salary, Netflix', 'नाम, जैसे किराया, वेतन, Netflix')),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ChipRow<TxnType>(
          value: _type,
          options: [(TxnType.expense, typeLabel(TxnType.expense)), (TxnType.income, typeLabel(TxnType.income))],
          onChanged: (v) => setState(() {
            _type = v;
            if (!categoryById(_categoryId, widget.data.expenseCategories.items).fits(v)) {
              _categoryId = v == TxnType.expense ? 'bills' : 'salary';
            }
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: tr(context, t('Amount each time', 'हर बार की राशि')),
            prefixText: '₹ ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        CategoryChips(
          data: widget.data,
          type: _type,
          selected: _categoryId,
          onChanged: (id) => setState(() => _categoryId = id ?? _categoryId),
        ),
        const SizedBox(height: 12),
        ChipRow<Frequency>(
          value: _frequency,
          options: [for (final f in Frequency.values) (f, frequencyLabel(f))],
          onChanged: (v) => setState(() => _frequency = v),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickStart,
          icon: const Icon(Icons.event_outlined),
          label: Text('${tr(context, t('Starts', 'शुरू'))}: ${fmtDate(_start)}'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _valid ? _submit : null, child: Text(tr(context, t('Save', 'सेव करें')))),
        ),
      ],
    );
  }
}
