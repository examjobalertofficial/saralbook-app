import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/l10n/ltext.dart';
import '../../../core/tools/countdown_model.dart';
import '../../../widgets/page_body.dart';
import '../../../widgets/tr.dart';

const String _prefsKey = 'tool_countdowns_v1';

/// Saves exam dates / last dates and shows how many days are left.
class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  List<CountdownItem> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _items = decodeCountdowns(p.getString(_prefsKey));
    } catch (_) {
      _items = [];
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, encodeCountdowns(_items));
    } catch (_) {/* keep working in memory */}
  }

  Future<void> _add() async {
    if (_items.length >= kMaxCountdowns) return;
    final title = TextEditingController();
    DateTime? date;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(tr(ctx, t('New date', 'नई तारीख'))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: tr(ctx, t('Exam or last date name', 'परीक्षा / अंतिम तिथि का नाम')),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_rounded),
                label: Text(date == null
                    ? tr(ctx, t('Choose date', 'तारीख चुनें'))
                    : _fmt(date!)),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 6),
                  );
                  if (d != null) setLocal(() => date = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(ctx, t('Cancel', 'रद्द करें')))),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isNotEmpty && date != null) Navigator.pop(ctx, true);
              },
              child: Text(tr(ctx, t('Save', 'सेव करें'))),
            ),
          ],
        ),
      ),
    );
    final picked = date;
    if (ok == true && picked != null) {
      setState(() {
        _items.add(CountdownItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title.text.trim(),
          date: picked,
        ));
      });
      await _save();
    }
    title.dispose();
  }

  Future<void> _remove(CountdownItem i) async {
    setState(() => _items.removeWhere((e) => e.id == i.id));
    await _save();
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final sorted = sortCountdowns(_items, today);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, t('Exam Countdown', 'परीक्षा काउंटडाउन')))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, t('Add date', 'तारीख जोड़ें'))),
      ),
      body: PageBody(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : sorted.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr(context, t(
                          'Add an exam or a form last date and see how many days are left.',
                          'परीक्षा या फ़ॉर्म की अंतिम तिथि जोड़ें और देखें कितने दिन बचे हैं।',
                        )),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final i = sorted[index];
                      final left = i.daysLeft(today);
                      final past = left < 0;
                      final soon = !past && left <= 7;
                      final bg = past
                          ? scheme.surfaceContainerHighest
                          : soon
                              ? scheme.errorContainer
                              : scheme.primaryContainer;
                      final fg = past
                          ? scheme.onSurfaceVariant
                          : soon
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                          leading: Container(
                            width: 64,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              past ? '—' : '$left',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg),
                            ),
                          ),
                          title: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            past
                                ? '${_fmt(i.date)} · ${tr(context, t('finished', 'हो चुका'))}'
                                : left == 0
                                    ? '${_fmt(i.date)} · ${tr(context, t('today', 'आज'))}'
                                    : '${_fmt(i.date)} · ${tr(context, t('days left', 'दिन बाकी'))}',
                          ),
                          trailing: IconButton(
                            tooltip: tr(context, t('Delete', 'हटाएं')),
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _remove(i),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
