import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/expense/currency.dart';
import '../../core/expense/models.dart';
import '../../core/expense/money.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/personal_data.dart';
import '../../core/tools/calc_math.dart' show fmtDate;
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'expense_ui.dart';

/// Add or edit one income / expense. [onSaved] gets the finished transaction.
Future<void> showTxnForm(
  BuildContext context, {
  required PersonalData data,
  ExpenseTxn? existing,
  TxnType type = TxnType.expense,
  required ValueChanged<ExpenseTxn> onSaved,
}) {
  return showFormSheet<void>(
    context,
    (ctx) => TxnForm(data: data, existing: existing, initialType: type, onSaved: onSaved),
  );
}

class TxnForm extends StatefulWidget {
  final PersonalData data;
  final ExpenseTxn? existing;
  final TxnType initialType;
  final ValueChanged<ExpenseTxn> onSaved;
  const TxnForm({super.key, required this.data, required this.existing, required this.initialType, required this.onSaved});

  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  late TxnType _type = widget.existing?.type ?? widget.initialType;
  late String _categoryId = widget.existing?.categoryId ?? (_type == TxnType.expense ? 'food' : 'salary');
  late DateTime _date = widget.existing == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(widget.existing!.date);
  late String _currency = widget.existing?.currency ?? 'INR';
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null ? '' : minorToPlain(widget.existing!.origMinor),
  );
  late final TextEditingController _rate = TextEditingController(
    text: widget.existing != null && widget.existing!.isForeign ? '${widget.existing!.rate}' : '',
  );
  late final TextEditingController _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _started = false;

  static final LText _newTitle = t('Add transaction', 'लेन-देन जोड़ें');
  static final LText _editTitle = t('Edit transaction', 'लेन-देन बदलें');
  static final LText _amountLabel = t('Amount', 'राशि');
  static final LText _currencyLabel = t('Currency', 'मुद्रा');
  static final LText _rateLabel = t('Rate: rupees for 1 unit', 'दर: 1 इकाई के रुपये');
  static final LText _noRate = t(
    'No rate available (offline). Type the rate yourself.',
    'दर उपलब्ध नहीं है (ऑफ़लाइन)। दर खुद लिखें।',
  );
  static final LText _noteHint = t('Note (optional)', 'नोट (वैकल्पिक)');
  static final LText _save = t('Save', 'सेव करें');
  static final LText _category = t('Category', 'श्रेणी');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // (not in initState: reading AppScope there is not allowed)
    if (!_started) {
      _started = true;
      if (_currency != 'INR') unawaited(_rates.refresh());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    _note.dispose();
    super.dispose();
  }

  RateService get _rates => AppScope.of(context).rates;

  double? get _rateValue {
    final v = double.tryParse(_rate.text.trim());
    return (v != null && v > 0 && v.isFinite) ? v : null;
  }

  void _setCurrency(String code) {
    setState(() {
      _currency = code;
      _rate.text = '';
    });
    if (code != 'INR') unawaited(_rates.refresh());
  }

  /// The rate typed by the person, otherwise the live / saved / manual rate.
  double? get _effectiveRate => _rateValue ?? _rates.inrPerUnit(_currency);

  String _rateHint() {
    final r = _rates.inrPerUnit(_currency);
    return r == null ? '' : r.toStringAsFixed(r < 1 ? 4 : 2);
  }

  int? get _orig => parseMinor(_amount.text);

  int? get _inrMinor {
    final o = _orig;
    if (o == null) return null;
    if (_currency == 'INR') return o;
    final r = _effectiveRate;
    if (r == null) return null;
    final v = (o * r).round();
    return v < 1 ? 1 : v;
  }

  bool get _valid => _inrMinor != null;

  void _submit() {
    final inr = _inrMinor;
    final orig = _orig;
    if (inr == null || orig == null) return;
    final note = _note.text.trim();
    final rate = _currency == 'INR' ? 1.0 : _effectiveRate!;
    final e = widget.existing;
    final saved = e == null
        ? ExpenseTxn.create(
            type: _type,
            amountMinor: inr,
            categoryId: _categoryId,
            note: note,
            date: _date,
            currency: _currency,
            origMinor: orig,
            rate: rate,
          )
        : e.copyWith(
            type: _type,
            amountMinor: inr,
            categoryId: _categoryId,
            note: note,
            date: _date,
            currency: _currency,
            origMinor: orig,
            rate: rate,
          );
    widget.onSaved(saved);
    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, widget.existing == null ? _newTitle : _editTitle),
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ChipRow<TxnType>(
          value: _type,
          options: [(TxnType.expense, typeLabel(TxnType.expense)), (TxnType.income, typeLabel(TxnType.income))],
          onChanged: (v) => setState(() {
            _type = v;
            if (!categoryById(_categoryId, widget.data.expenseCategories.items).fits(v)) {
              _categoryId = v == TxnType.expense ? 'food' : 'salary';
            }
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          autofocus: widget.existing == null,
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
            builder: (context, _) {
              final inr = _inrMinor;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: tr(context, _rateLabel),
                        hintText: _rateHint(),
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        helperText: _effectiveRate == null ? tr(context, _noRate) : null,
                        suffixIcon: _rates.refreshing
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (inr != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('= ${formatInr(inr)}', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 14),
        Text(tr(context, _category), style: text.labelLarge),
        const SizedBox(height: 6),
        CategoryChips(
          data: widget.data,
          type: _type,
          selected: _categoryId,
          onChanged: (id) => setState(() => _categoryId = id ?? _categoryId),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(fmtDate(_date)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: tr(context, _noteHint), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: _valid ? _submit : null, child: Text(tr(context, _save))),
        ),
      ],
    );
  }
}
