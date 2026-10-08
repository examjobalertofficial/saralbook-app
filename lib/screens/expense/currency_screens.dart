import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_services.dart';
import '../../core/expense/currency.dart';
import '../../core/l10n/ltext.dart';
import '../../core/tools/calc_math.dart' show fmt;
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart' show ChipRow;

/// Currency converter + exchange rates (live, last saved, or typed by hand).
/// Works without signing in and without internet (saved / manual rates).
class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final TextEditingController _amount = TextEditingController(text: '100');
  String _from = 'USD';
  String _to = 'INR';
  bool _started = false;

  static final LText _title = t('Currency Converter', 'मुद्रा कन्वर्टर');
  static final LText _amountLabel = t('Amount', 'राशि');
  static final LText _fromLabel = t('From', 'से');
  static final LText _toLabel = t('To', 'में');
  static final LText _rates = t('Exchange rates (rupees for 1 unit)', 'विनिमय दरें (1 इकाई के रुपये)');
  static final LText _noRate = t('Rate not available. Connect to the internet or enter a rate yourself below.', 'दर उपलब्ध नहीं। इंटरनेट से जुड़ें या नीचे खुद दर दर्ज करें।');
  static final LText _offline = t('Could not update. Showing the last saved rates.', 'अपडेट नहीं हो सका। पिछली सेव की गई दरें दिखाई जा रही हैं।');
  static final LText _setManual = t('Set your own rate', 'अपनी दर तय करें');
  static final LText _useLive = t('Use live rate', 'लाइव दर इस्तेमाल करें');
  static final LText _refresh = t('Refresh rates', 'दरें रीफ़्रेश करें');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(AppScope.of(context).rates.refresh());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _sourceText(BuildContext context, RateService s, String code) => tr(
        context,
        switch (s.sourceOf(code)) {
          RateSource.base => t('Base currency', 'मूल मुद्रा'),
          RateSource.manual => t('Your rate', 'आपकी दर'),
          RateSource.live => t('Live', 'लाइव'),
          RateSource.lastKnown => t('Last saved', 'पिछली सेव की गई'),
          RateSource.none => t('Not available', 'उपलब्ध नहीं'),
        },
      );

  String _updated(RateService s) {
    final at = s.updatedAt;
    if (at == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
  }

  Future<void> _editManual(BuildContext context, RateService s, String code) async {
    final initial = s.manualRate(code)?.toString() ?? (s.inrPerUnit(code)?.toStringAsFixed(2) ?? '');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => _RateDialog(code: code, initial: initial),
    );
    if (result != null && result > 0) await s.setManual(code, result);
  }

  @override
  Widget build(BuildContext context) {
    final rates = AppScope.of(context).rates;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          ListenableBuilder(
            listenable: rates,
            builder: (context, _) => rates.refreshing
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: tr(context, _refresh),
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => rates.refresh(force: true),
                  ),
          ),
        ],
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: rates,
          builder: (context, _) {
            final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
            final converted = amount == null ? null : rates.convert(amount, _from, _to);
            final oneRate = rates.convert(1, _from, _to);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: InputDecoration(labelText: tr(context, _amountLabel), border: const OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Text(tr(context, _fromLabel), style: text.labelLarge),
                const SizedBox(height: 6),
                ChipRow<String>(
                  value: _from,
                  options: [for (final c in supportedCurrencies) (c.code, LText({'en': c.code, 'hi': c.code}))],
                  onChanged: (v) => setState(() => _from = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.swap_vert_rounded),
                    onPressed: () => setState(() {
                      final x = _from;
                      _from = _to;
                      _to = x;
                    }),
                  ),
                ),
                Text(tr(context, _toLabel), style: text.labelLarge),
                const SizedBox(height: 6),
                ChipRow<String>(
                  value: _to,
                  options: [for (final c in supportedCurrencies) (c.code, LText({'en': c.code, 'hi': c.code}))],
                  onChanged: (v) => setState(() => _to = v),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: converted == null
                      ? Text(tr(context, _noRate), style: TextStyle(color: scheme.onPrimaryContainer))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SelectableText(
                                '${fmt(converted, maxDecimals: 2)} $_to',
                                style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (oneRate != null)
                              Text(
                                '1 $_from = ${fmt(oneRate, maxDecimals: 4)} $_to',
                                style: TextStyle(color: scheme.onPrimaryContainer),
                              ),
                          ],
                        ),
                ),
                if (rates.lastRefreshFailed && rates.hasLive)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr(context, _offline), style: TextStyle(color: scheme.onSurfaceVariant))),
                if (rates.updatedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${tr(context, t('Rates updated', 'दरें अपडेट हुईं'))}: ${_updated(rates)}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 22),
                Text(tr(context, _rates), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final c in supportedCurrencies)
                  if (c.code != 'INR')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${c.code}  •  ${c.name}'),
                      subtitle: Text(_sourceText(context, rates, c.code)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rates.inrPerUnit(c.code) == null ? '—' : '₹${fmt(rates.inrPerUnit(c.code)!, maxDecimals: 2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (rates.manualRate(c.code) != null)
                            IconButton(
                              tooltip: tr(context, _useLive),
                              icon: const Icon(Icons.restart_alt_rounded),
                              onPressed: () => rates.setManual(c.code, null),
                            ),
                          IconButton(
                            tooltip: tr(context, _setManual),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editManual(context, rates, c.code),
                          ),
                        ],
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

/// Asks for a rate typed by the person (its own widget so the text field is
/// cleaned up correctly when the dialog closes).
class _RateDialog extends StatefulWidget {
  final String code;
  final String initial;
  const _RateDialog({required this.code, required this.initial});

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('1 ${widget.code} = ₹ ?'),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: const InputDecoration(prefixText: '₹ ', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr(context, t('Cancel', 'रद्द करें')))),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(double.tryParse(_c.text.trim())),
          child: Text(tr(context, t('Save', 'सेव करें'))),
        ),
      ],
    );
  }
}
