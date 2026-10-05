import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/tools/calc_math.dart';
import '../../core/tools/calc_model.dart';
import '../../widgets/page_body.dart';

/// One screen that draws any calculator from its definition and shows the
/// result live while the user types. Works fully offline.
class CalcToolScreen extends StatefulWidget {
  final CalcTool tool;
  const CalcToolScreen({super.key, required this.tool});

  @override
  State<CalcToolScreen> createState() => _CalcToolScreenState();
}

class _CalcToolScreenState extends State<CalcToolScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _choices = {};
  final Map<String, DateTime?> _dates = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.tool.fields) {
      switch (f.kind) {
        case FieldKind.number:
        case FieldKind.text:
        case FieldKind.list:
          _controllers[f.id] = TextEditingController(text: f.defaultValue ?? '');
        case FieldKind.choice:
          _choices[f.id] = f.defaultValue ?? f.choices.first.id;
        case FieldKind.date:
          _dates[f.id] = f.defaultToday ? dateOnly(DateTime.now()) : null;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  CalcValues _values() => CalcValues(
        {
          for (final e in _controllers.entries) e.key: e.value.text,
          ..._choices,
        },
        Map<String, DateTime?>.of(_dates),
      );

  void _changed() => setState(() {});

  Future<void> _pickDate(CalcField f) async {
    final initial = _dates[f.id] ?? dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _dates[f.id] = dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    final s = AppStrings.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final values = _values();
    final visible = tool.fields.where((f) => tool.isVisible(f, values)).toList();
    final out = tool.run(values);

    return Scaffold(
      appBar: AppBar(
        title: Text(tool.title.of(lang), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (tool.note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _InfoBox(icon: Icons.info_outline_rounded, text: tool.note!.of(lang)),
              ),
            for (final f in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildField(f, lang, s),
              ),
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: _buildResult(out, lang, s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(CalcField f, String lang, AppStrings s) {
    final label = f.label.of(lang);
    switch (f.kind) {
      case FieldKind.number:
        return TextField(
          controller: _controllers[f.id],
          keyboardType: TextInputType.numberWithOptions(decimal: !f.integerOnly, signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(f.integerOnly ? r'[0-9,\-]' : r'[0-9.,\-]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            suffixText: f.suffix?.of(lang),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _changed(),
        );
      case FieldKind.text:
        return TextField(
          controller: _controllers[f.id],
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          onChanged: (_) => _changed(),
        );
      case FieldKind.list:
        return TextField(
          controller: _controllers[f.id],
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,;\s\-]')),
          ],
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _changed(),
        );
      case FieldKind.choice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in f.choices)
                  ChoiceChip(
                    label: Text(c.label.of(lang)),
                    selected: _choices[f.id] == c.id,
                    onSelected: (_) => setState(() => _choices[f.id] = c.id),
                  ),
              ],
            ),
          ],
        );
      case FieldKind.date:
        final date = _dates[f.id];
        final scheme = Theme.of(context).colorScheme;
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _pickDate(f),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: (f.optional && date != null)
                  ? IconButton(
                      tooltip: s.clear,
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _dates[f.id] = null),
                    )
                  : const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              date == null ? s.selectDate : fmtDate(date),
              style: TextStyle(color: date == null ? scheme.onSurfaceVariant : null),
            ),
          ),
        );
    }
  }

  Widget _buildResult(CalcOutput? out, String lang, AppStrings s) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (out == null) {
      return _InfoBox(icon: Icons.keyboard_alt_outlined, text: s.enterValues);
    }
    if (out.error != null) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(out.error!.of(lang), style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.resultTitle,
              style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            for (final line in out.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        line.label.of(lang),
                        style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: SelectableText(
                        line.valueFor(lang),
                        textAlign: TextAlign.end,
                        style: (line.highlight ? text.titleLarge : text.titleMedium)?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: line.highlight ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final n in out.notes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(n.of(lang), style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}
