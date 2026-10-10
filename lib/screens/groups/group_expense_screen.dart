import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/expense/currency.dart';
import '../../core/expense/money.dart';
import '../../core/groups/group_controllers.dart';
import '../../core/groups/group_logic.dart';
import '../../core/groups/group_models.dart';
import '../../core/l10n/ltext.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../expense/expense_ui.dart';
import '../study/personal_ui.dart';
import 'group_ui.dart';

/// Add a new bill, or change [existing].
class GroupExpenseScreen extends StatefulWidget {
  final GroupSession session;
  final GroupExpense? existing;
  const GroupExpenseScreen({super.key, required this.session, this.existing});

  @override
  State<GroupExpenseScreen> createState() => _GroupExpenseScreenState();
}

class _GroupExpenseScreenState extends State<GroupExpenseScreen> {
  late final List<GroupMember> _people;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _rate = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late String _currency;
  late String _categoryId;
  late DateTime _date;
  late SplitType _splitType;
  late String _payer;
  bool _multiPayer = false;
  bool _started = false;
  final Set<String> _included = {};
  final Map<String, TextEditingController> _exact = {};
  final Map<String, TextEditingController> _percent = {};
  final Map<String, TextEditingController> _paid = {};

  static final LText _newTitle = t('Add expense', 'खर्च जोड़ें');
  static final LText _editTitle = t('Edit expense', 'खर्च बदलें');
  static final LText _whatFor = t('What was it for?', 'किसलिए था?');
  static final LText _amountLabel = t('Total amount', 'कुल राशि');
  static final LText _currencyLabel = t('Currency', 'मुद्रा');
  static final LText _rateLabel = t('Rate: rupees for 1 unit', 'दर: 1 इकाई के रुपये');
  static final LText _noRate = t('No rate available (offline). Type the rate yourself.', 'दर उपलब्ध नहीं है (ऑफ़लाइन)। दर खुद लिखें।');
  static final LText _paidBy = t('Paid by', 'किसने भुगतान किया');
  static final LText _multiple = t('Several people paid', 'कई लोगों ने भुगतान किया');
  static final LText _splitLabel = t('Split', 'बंटवारा');
  static final LText _category = t('Category', 'श्रेणी');
  static final LText _noteHint = t('Note (optional)', 'नोट (वैकल्पिक)');
  static final LText _save = t('Save', 'सेव करें');
  static final LText _failed = t('Could not save. Check the amounts.', 'सेव नहीं हो सका। राशि जांचें।');

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    final e = widget.existing;
    final people = [...s.members];
    if (e != null) {
      // people who left the group but are in this old bill stay editable
      for (final id in {...e.paidBy.keys, ...e.splits.keys}) {
        if (people.every((m) => m.uid != id)) {
          people.add(GroupMember(uid: id, name: s.nameOf(id), role: GroupRole.member, joinedAt: 0));
        }
      }
    }
    _people = people;
    _currency = e?.currency ?? 'INR';
    _categoryId = e?.categoryId ?? 'food';
    _date = e == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(e.date);
    _splitType = e?.splitType ?? SplitType.equal;
    _payer = e == null || e.paidBy.length != 1 ? s.me.uid : e.paidBy.keys.first;
    _multiPayer = e != null && e.paidBy.length > 1;
    if (e != null) {
      _title.text = e.title;
      _amount.text = minorToPlain(e.origMinor);
      if (e.isForeign) _rate.text = '${e.rate}';
      _note.text = e.note;
    }
    for (final m in _people) {
      _exact[m.uid] = TextEditingController(text: e != null && e.splitType == SplitType.exact && e.splits.containsKey(m.uid) ? minorToPlain(e.splits[m.uid]!) : '');
      _percent[m.uid] = TextEditingController(
        text: e != null && e.splitType == SplitType.percent && e.percents.containsKey(m.uid) ? _trimNum(e.percents[m.uid]!) : '',
      );
      _paid[m.uid] = TextEditingController(text: e != null && e.paidBy.length > 1 && e.paidBy.containsKey(m.uid) ? minorToPlain(e.paidBy[m.uid]!) : '');
      if (e == null || e.splits.containsKey(m.uid)) _included.add(m.uid);
    }
  }

  static String _trimNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (_currency != 'INR') unawaited(_rates.refresh());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _rate.dispose();
    _note.dispose();
    for (final c in [..._exact.values, ..._percent.values, ..._paid.values]) {
      c.dispose();
    }
    super.dispose();
  }

  RateService get _rates => AppScope.of(context).rates;

  // ---------- money ----------

  int? get _orig => parseMinor(_amount.text);

  double? get _effectiveRate => double.tryParse(_rate.text.trim()) ?? _rates.inrPerUnit(_currency);

  int? get _total {
    final o = _orig;
    if (o == null) return null;
    if (_currency == 'INR') return o;
    final r = _effectiveRate;
    if (r == null || !(r > 0) || !r.isFinite) return null;
    final v = (o * r).round();
    return v < 1 ? 1 : v;
  }

  /// Empty = 0. A bad number = -1 (so checks fail).
  int _minorOrZero(String text) {
    final s = text.trim();
    if (s.isEmpty) return 0;
    final v = parseMinor(s);
    if (v != null) return v;
    final z = double.tryParse(s.replaceAll(',', ''));
    return z == 0 ? 0 : -1;
  }

  double _pctOrZero(String text) {
    final s = text.trim();
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? -1;
  }

  Map<String, int>? _computePaid(int total) {
    if (!_multiPayer) return {_payer: total};
    final m = <String, int>{for (final p in _people) p.uid: _minorOrZero(_paid[p.uid]!.text)};
    return checkAmounts(total, m) == SplitProblem.none ? withoutZero(m) : null;
  }

  Map<String, int>? _computeSplits(int total) {
    switch (_splitType) {
      case SplitType.equal:
        return _included.isEmpty ? null : splitEqual(total, _included);
      case SplitType.exact:
        final m = <String, int>{for (final p in _people) p.uid: _minorOrZero(_exact[p.uid]!.text)};
        return checkAmounts(total, m) == SplitProblem.none ? withoutZero(m) : null;
      case SplitType.percent:
        final pct = <String, double>{for (final p in _people) p.uid: _pctOrZero(_percent[p.uid]!.text)};
        final r = splitByPercent(total, pct);
        return r == null ? null : withoutZero(r);
    }
  }

  Map<String, double> _typedPercents() => {
        for (final p in _people)
          if (_pctOrZero(_percent[p.uid]!.text) > 0) p.uid: _pctOrZero(_percent[p.uid]!.text),
      };

  bool get _valid {
    final total = _total;
    if (total == null || _title.text.trim().isEmpty) return false;
    return _computePaid(total) != null && _computeSplits(total) != null;
  }

  void _submit() {
    final total = _total;
    final orig = _orig;
    if (total == null || orig == null) return;
    final paid = _computePaid(total);
    final splits = _computeSplits(total);
    if (paid == null || splits == null) return;
    final ok = widget.session.saveExpense(
      existing: widget.existing,
      title: _title.text,
      amountMinor: total,
      currency: _currency,
      origMinor: orig,
      rate: _currency == 'INR' ? 1.0 : _effectiveRate!,
      categoryId: _categoryId,
      date: DateTime(_date.year, _date.month, _date.day, 12).millisecondsSinceEpoch,
      paidBy: paid,
      splits: splits,
      splitType: _splitType,
      percents: _splitType == SplitType.percent ? _typedPercents() : const {},
      note: _note.text,
    );
    if (ok) {
      Navigator.of(context).pop();
    } else {
      showSnack(context, _failed, error: true);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _setCurrency(String code) {
    setState(() {
      _currency = code;
      _rate.text = '';
    });
    if (code != 'INR') unawaited(_rates.refresh());
  }

  // ---------- build ----------

  Widget _personRow(GroupMember m, {required Widget trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            MemberAvatar(member: m, radius: 16),
            const SizedBox(width: 10),
            Expanded(child: Text(m.uid == widget.session.me.uid ? '${m.name} (${tr(context, youLabel)})' : m.name, overflow: TextOverflow.ellipsis)),
            trailing,
          ],
        ),
      );

  Widget _amountField(TextEditingController c, {String prefix = '₹ '}) => SizedBox(
        width: 120,
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          decoration: InputDecoration(isDense: true, prefixText: prefix, border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
      );

  Widget _helper(String text, bool ok) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: TextStyle(color: ok ? scheme.primary : scheme.error, fontWeight: FontWeight.w600)),
    );
  }

  Widget _paidSection(int? total) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, _paidBy), style: text.labelLarge),
        const SizedBox(height: 6),
        if (!_multiPayer)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final m in _people)
                ChoiceChip(
                  label: Text(m.uid == widget.session.me.uid ? tr(context, youLabel) : m.name),
                  selected: m.uid == _payer,
                  onSelected: (_) => setState(() => _payer = m.uid),
                ),
            ],
          )
        else ...[
          for (final m in _people) _personRow(m, trailing: _amountField(_paid[m.uid]!)),
          if (total != null)
            Builder(builder: (context) {
              final sum = _people.fold<int>(0, (a, m) => a + (_minorOrZero(_paid[m.uid]!.text).clamp(0, maxMinor).toInt()));
              return _helper('${formatInr(sum)} / ${formatInr(total)}', sum == total);
            }),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr(context, _multiple)),
          value: _multiPayer,
          onChanged: (v) => setState(() => _multiPayer = v),
        ),
      ],
    );
  }

  Widget _splitSection(int? total) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, _splitLabel), style: text.labelLarge),
        const SizedBox(height: 6),
        ChipRow<SplitType>(
          value: _splitType,
          options: [for (final s in SplitType.values) (s, splitTypeLabel(s))],
          onChanged: (v) => setState(() => _splitType = v),
        ),
        const SizedBox(height: 8),
        if (_splitType == SplitType.equal) ...[
          for (final m in _people)
            _personRow(
              m,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (total != null && _included.contains(m.uid))
                    Text(formatInr(splitEqual(total, _included)[m.uid] ?? 0), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Checkbox(
                    value: _included.contains(m.uid),
                    onChanged: (v) => setState(() => v == true ? _included.add(m.uid) : _included.remove(m.uid)),
                  ),
                ],
              ),
            ),
          if (_included.isEmpty) _helper(tr(context, t('Choose at least one person', 'कम से कम एक व्यक्ति चुनें')), false),
        ] else if (_splitType == SplitType.exact) ...[
          for (final m in _people) _personRow(m, trailing: _amountField(_exact[m.uid]!)),
          if (total != null)
            Builder(builder: (context) {
              final sum = _people.fold<int>(0, (a, m) => a + (_minorOrZero(_exact[m.uid]!.text).clamp(0, maxMinor).toInt()));
              final left = total - sum;
              return _helper(
                left == 0
                    ? '${formatInr(sum)} / ${formatInr(total)}'
                    : '${formatInr(sum)} / ${formatInr(total)}  (${tr(context, t(left > 0 ? 'left' : 'extra', left > 0 ? 'बाकी' : 'ज़्यादा'))} ${formatInr(left.abs())})',
                left == 0,
              );
            }),
        ] else ...[
          for (final m in _people) _personRow(m, trailing: _amountField(_percent[m.uid]!, prefix: '% ')),
          Builder(builder: (context) {
            final sum = percentTotal([for (final m in _people) _pctOrZero(_percent[m.uid]!.text).clamp(0, 1000).toDouble()]);
            return _helper('${_trimNum(sum)} % / 100 %', (sum - 100).abs() < 0.005);
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = _total;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, widget.existing == null ? _newTitle : _editTitle), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr(context, _whatFor), border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: tr(context, _amountLabel),
                prefixText: _currency == 'INR' ? '₹ ' : '$_currency ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Text(tr(context, _currencyLabel), style: text.labelLarge),
            const SizedBox(height: 6),
            ChipRow<String>(
              value: _currency,
              options: [for (final c in supportedCurrencies) (c.code, LText({'en': c.code, 'hi': c.code}))],
              onChanged: _setCurrency,
            ),
            if (_currency != 'INR')
              ListenableBuilder(
                listenable: _rates,
                builder: (context, _) => Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _rate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: tr(context, _rateLabel),
                          hintText: _rates.inrPerUnit(_currency)?.toStringAsFixed(2) ?? '',
                          prefixText: '₹ ',
                          border: const OutlineInputBorder(),
                          helperText: _effectiveRate == null ? tr(context, _noRate) : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (total != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('= ${formatInr(total)}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _paidSection(total),
            const SizedBox(height: 8),
            _splitSection(total),
            const SizedBox(height: 14),
            Text(tr(context, _category), style: text.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in groupCategories)
                  ChoiceChip(
                    avatar: Icon(categoryIcon(c.iconKey), size: 18),
                    label: Text(categoryName(context, c)),
                    selected: c.id == _categoryId,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_outlined), label: Text(fmtDate(_date))),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: tr(context, _noteHint), border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _valid ? _submit : null, child: Text(tr(context, _save))),
          ],
        ),
      ),
    );
  }
}
