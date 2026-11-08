import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/ltext.dart';
import '../../../core/tools/text_stats.dart';
import '../../../widgets/page_body.dart';
import '../../../widgets/tr.dart';

/// Word counter and quick text clean-ups.
class TextToolsScreen extends StatefulWidget {
  const TextToolsScreen({super.key});

  @override
  State<TextToolsScreen> createState() => _TextToolsScreenState();
}

class _TextToolsScreenState extends State<TextToolsScreen> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _apply(String Function(String) f) {
    setState(() => _c.text = f(_c.text));
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.of(context);
    final msg = tr(context, t('Copied', 'कॉपी हो गया'));
    await Clipboard.setData(ClipboardData(text: _c.text));
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final text = d?.text;
    if (text != null && mounted) setState(() => _c.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final s = analyseText(_c.text);
    final mins = s.readingSeconds ~/ 60;
    final secs = s.readingSeconds % 60;
    Widget stat(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );
    Widget chip(LText label, String Function(String) f) => ActionChip(
          label: Text(tr(context, label)),
          onPressed: () => _apply(f),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, t('Text Tools', 'टेक्स्ट टूल्स')))),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _c,
              minLines: 6,
              maxLines: 12,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: tr(context, t('Type or paste your text here', 'यहां टेक्स्ट लिखें या पेस्ट करें')),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: Text(tr(context, t('Paste', 'पेस्ट'))),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _c.text.isEmpty ? null : _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(tr(context, t('Copy', 'कॉपी'))),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _c.text.isEmpty ? null : () => setState(_c.clear),
                  child: Text(tr(context, t('Clear', 'साफ़ करें'))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Column(
                  children: [
                    Row(children: [
                      stat(tr(context, t('Words', 'शब्द')), '${s.words}'),
                      stat(tr(context, t('Characters', 'अक्षर')), '${s.characters}'),
                      stat(tr(context, t('No spaces', 'बिना स्पेस')), '${s.charactersNoSpaces}'),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      stat(tr(context, t('Sentences', 'वाक्य')), '${s.sentences}'),
                      stat(tr(context, t('Lines', 'पंक्तियां')), '${s.lines}'),
                      stat(tr(context, t('Reading time', 'पढ़ने का समय')), mins > 0 ? '${mins}m ${secs}s' : '${secs}s'),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr(context, t('Quick clean-up', 'तुरंत सुधार')),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip(t('UPPER CASE', 'बड़े अक्षर'), (x) => x.toUpperCase()),
                chip(t('lower case', 'छोटे अक्षर'), (x) => x.toLowerCase()),
                chip(t('Title Case', 'टाइटल केस'), toTitleCase),
                chip(t('Sentence case', 'वाक्य केस'), toSentenceCase),
                chip(t('Remove extra spaces', 'फालतू स्पेस हटाएं'), cleanSpaces),
                chip(t('Remove duplicate lines', 'दोहरी पंक्तियां हटाएं'), removeDuplicateLines),
                chip(t('Sort lines A-Z', 'पंक्तियां A-Z'), sortLines),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
