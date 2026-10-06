import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/files/file_helpers.dart';
import '../../core/l10n/ltext.dart';
import '../../core/personal/personal_data.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../study/personal_ui.dart';

final LText _title = t('My data', 'मेरा डेटा');

/// Export a copy of everything, or delete all cloud data of this account.
class AccountDataScreen extends StatefulWidget {
  const AccountDataScreen({super.key});

  @override
  State<AccountDataScreen> createState() => _AccountDataScreenState();
}

class _AccountDataScreenState extends State<AccountDataScreen> {
  bool _busy = false;

  static final LText _exportTitle = t('Export my data', 'मेरा डेटा एक्सपोर्ट करें');
  static final LText _exportBody = t(
    'Saves a file with your notes, tasks, study plans, exams and favorites. You can keep or share it.',
    'आपके नोट्स, टास्क, स्टडी प्लान, परीक्षाओं और पसंदीदा की एक फ़ाइल बनाता है। आप इसे रख या शेयर कर सकते हैं।',
  );
  static final LText _deleteTitle = t('Delete my data', 'मेरा डेटा हटाएं');
  static final LText _deleteBody = t(
    'Permanently deletes your notes, tasks, study plans, study time, exams, favorites and saved settings from the cloud. This cannot be undone.',
    'आपके नोट्स, टास्क, स्टडी प्लान, पढ़ाई का समय, परीक्षाएं, पसंदीदा और सेव की गई सेटिंग्स क्लाउड से हमेशा के लिए हटा देता है। इसे वापस नहीं किया जा सकता।',
  );
  static final LText _warnTitle = t('Delete all your data?', 'अपना सारा डेटा हटाएं?');
  static final LText _warnBody = t(
    'Everything stored in your account will be erased. We suggest exporting a copy first.',
    'आपके अकाउंट में सेव सब कुछ मिट जाएगा। पहले एक कॉपी एक्सपोर्ट करने की सलाह है।',
  );
  static final LText _typePrompt = t('Type DELETE to confirm', 'पुष्टि के लिए DELETE लिखें');
  static final LText _cancel = t('Cancel', 'रद्द करें');
  static final LText _continue = t('Continue', 'आगे बढ़ें');
  static final LText _deleteNow = t('Delete forever', 'हमेशा के लिए हटाएं');
  static final LText _exportFirst = t('Export first', 'पहले एक्सपोर्ट करें');
  static final LText _done = t('Your cloud data was deleted.', 'आपका क्लाउड डेटा हटा दिया गया।');
  static final LText _noNet = t(
    'Could not finish. Connect to the internet and try again. Nothing was signed out.',
    'पूरा नहीं हो सका। इंटरनेट से जुड़कर फिर कोशिश करें। आप साइन आउट नहीं हुए हैं।',
  );
  static final LText _exportFail = t('Could not create the file.', 'फ़ाइल नहीं बन सकी।');

  Future<void> _export(PersonalData data) async {
    final messenger = ScaffoldMessenger.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() => _busy = true);
    try {
      final json = const JsonEncoder.withIndent('  ').convert(data.exportAll());
      final out = await writeOutput('saralbook_my_data.json', Uint8List.fromList(utf8.encode(json)));
      await shareOutputs([out]);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(_exportFail.of(lang))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(PersonalData data) async {
    final services = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final lang = Localizations.localeOf(context).languageCode;

    // step 1: warning (with a chance to export)
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: Theme.of(ctx).colorScheme.error),
        title: Text(tr(ctx, _warnTitle)),
        content: Text(tr(ctx, _warnBody)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('cancel'), child: Text(tr(ctx, _cancel))),
          TextButton(onPressed: () => Navigator.of(ctx).pop('export'), child: Text(tr(ctx, _exportFirst))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop('continue'), child: Text(tr(ctx, _continue))),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'export') {
      await _export(data);
      return;
    }
    if (choice != 'continue') return;

    // step 2: final confirmation, must type DELETE
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _TypeDeleteDialog(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await data.deleteAll().timeout(const Duration(seconds: 25));
      await services.sync.deleteProfile().timeout(const Duration(seconds: 15));
      await services.auth.signOut();
      messenger.showSnackBar(SnackBar(content: Text(_done.of(lang))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(_noNet.of(lang))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PersonalGate(
      title: _title,
      builder: (context, data) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
          body: PageBody(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(context, _exportTitle), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(tr(context, _exportBody)),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _export(data),
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(tr(context, _exportTitle)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  elevation: 0,
                  color: scheme.errorContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, _deleteTitle),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onErrorContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(tr(context, _deleteBody), style: TextStyle(color: scheme.onErrorContainer)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                          onPressed: _busy ? null : () => _delete(data),
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: Text(tr(context, _deleteTitle)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TypeDeleteDialog extends StatefulWidget {
  const _TypeDeleteDialog();

  @override
  State<_TypeDeleteDialog> createState() => _TypeDeleteDialogState();
}

class _TypeDeleteDialogState extends State<_TypeDeleteDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _c.text.trim() == 'DELETE';
    return AlertDialog(
      title: Text(tr(context, _AccountDataScreenState._typePrompt)),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'DELETE'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr(context, _AccountDataScreenState._cancel))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: Text(tr(context, _AccountDataScreenState._deleteNow)),
        ),
      ],
    );
  }
}
