import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' show PdfPasswordException;

import '../../../core/files/file_helpers.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/tools/files/image_ops.dart';
import '../../../core/tools/files/pdf_ops.dart';
import '../../../widgets/page_body.dart';

String tx(BuildContext c, LText x) => x.of(Localizations.localeOf(c).languageCode);

/// Words used by the PDF & image tools (English + Hindi).
class Tx {
  static final offlineNote = t(
    'Works offline. Your files never leave your phone.',
    'ऑफ़लाइन काम करता है। आपकी फ़ाइलें आपके फ़ोन से बाहर नहीं जातीं।',
  );
  static final choosePdf = t('Choose PDF', 'PDF चुनें');
  static final choosePdfs = t('Choose PDF files', 'PDF फ़ाइलें चुनें');
  static final chooseImage = t('Choose picture', 'फ़ोटो चुनें');
  static final chooseImages = t('Choose pictures', 'फ़ोटो चुनें');
  static final addMore = t('Add more', 'और जोड़ें');
  static final change = t('Change', 'बदलें');
  static final remove = t('Remove', 'हटाएं');
  static final dragToReorder = t('Hold and drag to change the order', 'क्रम बदलने के लिए दबाकर खींचें');
  static final readyTitle = t('Your file is ready', 'आपकी फ़ाइल तैयार है');
  static final readyTitleMany = t('Your files are ready', 'आपकी फ़ाइलें तैयार हैं');
  static final save = t('Save', 'सेव करें');
  static final share = t('Share', 'शेयर करें');
  static final shareAll = t('Share all', 'सभी शेयर करें');
  static final saved = t('Saved', 'सेव हो गया');
  static final notSaved = t('Not saved', 'सेव नहीं हुआ');
  static final working = t('Working…', 'काम हो रहा है…');
  static final pages = t('Pages', 'पेज');
  static final fileSize = t('File size', 'फ़ाइल का आकार');
  static final pageSize = t('Page size', 'पेज का आकार');
  static final before = t('Before', 'पहले');
  static final after = t('After', 'बाद में');
  static final saving = t('Saved', 'बचत');
  static final notSmaller = t(
    'The new file is not smaller. Keep your original.',
    'नई फ़ाइल छोटी नहीं हुई। अपनी मूल फ़ाइल रखें।',
  );
  static final errPassword = t(
    'This PDF is password protected. Remove the password first.',
    'यह PDF पासवर्ड से सुरक्षित है। पहले पासवर्ड हटाएं।',
  );
  static final errTooBig = t(
    'This file is too large to process on the phone.',
    'यह फ़ाइल फ़ोन पर प्रोसेस करने के लिए बहुत बड़ी है।',
  );
  static final errUnreadable = t(
    'This file could not be read. It may be damaged or in an unsupported format.',
    'यह फ़ाइल पढ़ी नहीं जा सकी। यह खराब हो सकती है या फ़ॉर्मैट समर्थित नहीं है।',
  );
  static final errGeneric = t(
    'Something went wrong. Please try again.',
    'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।',
  );
  static final errRange = t(
    'Please check the page numbers, for example 1-3, 5, 8-',
    'कृपया पेज नंबर जांचें, जैसे 1-3, 5, 8-',
  );
  static final pageNumbers = t('Pages (e.g. 1-3, 5, 8-)', 'पेज (जैसे 1-3, 5, 8-)');
  static final jpg = t('JPG', 'JPG');
  static final png = t('PNG', 'PNG');
}

/// Turns any error into a friendly message.
LText describeError(Object e) {
  if (e is PdfPasswordException) return Tx.errPassword;
  if (e is PdfTooLargeException || e is ImageTooLargeException) return Tx.errTooBig;
  if (e is FormatException) return Tx.errUnreadable;
  return Tx.errGeneric;
}

class JobResult {
  final List<OutputFile> files;
  final List<(LText, String)> info;
  final List<LText> warnings;
  const JobResult(this.files, {this.info = const [], this.warnings = const []});
}

/// Shared "working / error / result" behaviour for the tool screens.
mixin ToolRunner<T extends StatefulWidget> on State<T> {
  bool busy = false;
  LText? errorText;
  double? progressValue;
  String? progressLabel;
  JobResult? result;

  void clearResult() {
    result = null;
    errorText = null;
  }

  void reportProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      progressValue = total == 0 ? null : done / total;
      progressLabel = '$done / $total';
    });
  }

  Future<void> runJob(Future<JobResult> Function() job) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      errorText = null;
      result = null;
      progressValue = null;
      progressLabel = null;
    });
    try {
      await cleanOldOutputs();
      final r = await job();
      if (!mounted) return;
      setState(() => result = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = describeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Widget> statusWidgets(BuildContext context) => [
        if (busy)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progressValue),
                const SizedBox(height: 6),
                Text('${tx(context, Tx.working)} ${progressLabel ?? ''}'),
              ],
            ),
          ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: NoteBox(
              icon: Icons.error_outline_rounded,
              text: tx(context, errorText!),
              error: true,
            ),
          ),
        if (result != null) OutputPanel(result: result!),
      ];
}

class ToolPage extends StatelessWidget {
  final LText title;
  final List<Widget> children;
  const ToolPage({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, title), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            NoteBox(icon: Icons.lock_outline_rounded, text: tx(context, Tx.offlineNote)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class NoteBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;
  const NoteBox({super.key, required this.icon, required this.text, this.error = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = error ? scheme.errorContainer : scheme.surfaceContainerHighest;
    final fg = error ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: fg))),
        ],
      ),
    );
  }
}

class ChoiceRow<V> extends StatelessWidget {
  final LText label;
  final List<(V, LText)> options;
  final V value;
  final ValueChanged<V> onChanged;
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx(context, label), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(tx(context, o.$2)),
                  selected: o.$1 == value,
                  onSelected: (_) => onChanged(o.$1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class NumField extends StatelessWidget {
  final TextEditingController controller;
  final LText label;
  final String? suffix;
  final bool decimal;
  final ValueChanged<String>? onChanged;
  const NumField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.decimal = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
        ],
        decoration: InputDecoration(
          labelText: tx(context, label),
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

int? parseInt(TextEditingController c) => int.tryParse(c.text.trim());
double? parseDouble(TextEditingController c) => double.tryParse(c.text.trim());

class PickButton extends StatelessWidget {
  final LText label;
  final IconData icon;
  final VoidCallback? onPressed;
  const PickButton({super.key, required this.label, required this.onPressed, this.icon = Icons.folder_open_rounded});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(tx(context, label)),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final LText label;
  final IconData icon;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.enabled = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (enabled && !busy) ? onPressed : null,
        icon: Icon(icon),
        label: Text(tx(context, label)),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}

/// A picked file shown as a card.
class PickedCard extends StatelessWidget {
  final PickedFile file;
  final IconData icon;
  final Widget? trailing;
  const PickedCard({super.key, required this.file, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(formatBytes(file.size)),
        trailing: trailing,
      ),
    );
  }
}

/// Re-orderable list of picked files (PDFs or pictures).
class OrderedFileList extends StatelessWidget {
  final List<PickedFile> files;
  final ValueChanged<List<PickedFile>> onChanged;
  final bool images;
  const OrderedFileList({super.key, required this.files, required this.onChanged, required this.images});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            tx(context, Tx.dragToReorder),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          onReorder: (oldIndex, newIndex) {
            final list = List<PickedFile>.of(files);
            if (newIndex > oldIndex) newIndex -= 1;
            list.insert(newIndex, list.removeAt(oldIndex));
            onChanged(list);
          },
          itemBuilder: (context, i) {
            final f = files[i];
            return Card(
              key: ValueKey(f.path),
              elevation: 0,
              color: scheme.surfaceContainerLow,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: ListTile(
                leading: images
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(f.path),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 96,
                          errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
                        ),
                      )
                    : Icon(Icons.picture_as_pdf_rounded, color: scheme.error),
                title: Text('${i + 1}. ${f.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(formatBytes(f.size)),
                trailing: IconButton(
                  tooltip: tx(context, Tx.remove),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => onChanged(List<PickedFile>.of(files)..removeAt(i)),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Shows the finished files with Save / Share buttons.
class OutputPanel extends StatelessWidget {
  final JobResult result;
  const OutputPanel({super.key, required this.result});

  Future<void> _save(BuildContext context, OutputFile f) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await saveCopy(f);
    } catch (_) {
      ok = false;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(tx(context, ok ? Tx.saved : Tx.notSaved))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final files = result.files;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx(context, files.length > 1 ? Tx.readyTitleMany : Tx.readyTitle),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final line in result.info)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx(context, line.$1),
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                      Text(
                        line.$2,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final w in result.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(tx(context, w), style: TextStyle(color: scheme.onPrimaryContainer)),
                ),
              const SizedBox(height: 8),
              for (final f in files)
                Card(
                  elevation: 0,
                  color: scheme.surface,
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        if (f.mimeType.startsWith('image/'))
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(f.path),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                cacheWidth: 96,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined),
                              ),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.picture_as_pdf_rounded),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                formatBytes(f.size),
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: tx(context, Tx.save),
                          icon: const Icon(Icons.download_rounded),
                          onPressed: () => _save(context, f),
                        ),
                        IconButton(
                          tooltip: tx(context, Tx.share),
                          icon: const Icon(Icons.share_rounded),
                          onPressed: () => shareOutputs([f]),
                        ),
                      ],
                    ),
                  ),
                ),
              if (files.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => shareOutputs(files),
                      icon: const Icon(Icons.share_rounded),
                      label: Text(tx(context, Tx.shareAll)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
