import 'package:flutter/material.dart';

import '../../core/expense/models.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';
import 'expense_ui.dart';

final LText _title = t('Categories', 'श्रेणियां');

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PersonalGate(title: _title, builder: (context, data) => _Categories(data: data));
}

class _Categories extends StatelessWidget {
  final PersonalData data;
  const _Categories({required this.data});

  static final LText _add = t('Add category', 'श्रेणी जोड़ें');
  static final LText _mine = t('My categories', 'मेरी श्रेणियां');
  static final LText _builtIn = t('Built-in', 'पहले से मौजूद');
  static final LText _none = t('You have not added any categories.', 'आपने कोई श्रेणी नहीं जोड़ी।');
  static final LText _deleteQ = t(
    'Delete this category? Past transactions keep their amounts and show as "Other".',
    'यह श्रेणी हटाएं? पुराने लेन-देन की राशि बनी रहेगी और वे "अन्य" दिखेंगे।',
  );

  String _kindText(BuildContext context, CategoryKind k) => tr(
        context,
        switch (k) {
          CategoryKind.expense => t('Expense', 'खर्च'),
          CategoryKind.income => t('Income', 'आय'),
          CategoryKind.both => t('Both', 'दोनों'),
        },
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFormSheet<void>(context, (ctx) => _CategoryForm(data: data)),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, _add)),
      ),
      body: PageBody(
        child: ListenableBuilder(
          listenable: data.expenseCategories,
          builder: (context, _) {
            final custom = List<CustomCategory>.of(data.expenseCategories.items)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tr(context, _mine), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (custom.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(tr(context, _none), style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                for (final c in custom)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: categoryColor(c.toInfo()).withAlpha(36),
                      child: Icon(Icons.label_rounded, color: categoryColor(c.toInfo())),
                    ),
                    title: Text(c.name),
                    subtitle: Text(_kindText(context, c.kind)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(tr(ctx, _deleteQ)),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, t('Cancel', 'रद्द करें')))),
                              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr(ctx, t('Delete', 'हटाएं')))),
                            ],
                          ),
                        );
                        if (yes == true) data.expenseCategories.remove(c.id);
                      },
                    ),
                  ),
                const Divider(height: 28),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tr(context, _builtIn), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (final c in defaultCategories)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: categoryColor(c).withAlpha(36),
                      child: Icon(categoryIcon(c.iconKey), color: categoryColor(c)),
                    ),
                    title: Text(categoryName(context, c)),
                    subtitle: Text(_kindText(context, c.kind)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  final PersonalData data;
  const _CategoryForm({required this.data});

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final TextEditingController _name = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  int _color = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.data.expenseCategories.upsert(CustomCategory.create(name: name, kind: _kind, colorIndex: _color));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, t('New category', 'नई श्रेणी')),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: tr(context, t('Category name', 'श्रेणी का नाम')), border: const OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        ChipRow<CategoryKind>(
          value: _kind,
          options: [
            (CategoryKind.expense, t('Expense', 'खर्च')),
            (CategoryKind.income, t('Income', 'आय')),
            (CategoryKind.both, t('Both', 'दोनों')),
          ],
          onChanged: (v) => setState(() => _kind = v),
        ),
        const SizedBox(height: 12),
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
