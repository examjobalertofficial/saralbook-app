import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/ltext.dart';
import '../../../core/tools/kruti_dev.dart';
import '../../../widgets/page_body.dart';
import '../../../widgets/tr.dart';

/// Converts text typed in Kruti Dev into Unicode Hindi (works offline).
class KrutiDevScreen extends StatefulWidget {
  const KrutiDevScreen({super.key});

  @override
  State<KrutiDevScreen> createState() => _KrutiDevScreenState();
}

class _KrutiDevScreenState extends State<KrutiDevScreen> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final text = d?.text;
    if (text != null && mounted) setState(() => _c.text = text);
  }

  Future<void> _copy(String out) async {
    final messenger = ScaffoldMessenger.of(context);
    final msg = tr(context, t('Copied', 'कॉपी हो गया'));
    await Clipboard.setData(ClipboardData(text: out));
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final out = krutiDevToUnicode(_c.text);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, t('Kruti Dev to Unicode', 'कृतिदेव से यूनिकोड')))),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tr(context, t(
                  'Beta: paste text typed in Kruti Dev (looks like "Hkkjr ljdkj") to get Unicode Hindi. Check important text once after converting.',
                  'बीटा: कृतिदेव में टाइप किया टेक्स्ट (जैसे "Hkkjr ljdkj") पेस्ट करें और यूनिकोड हिंदी पाएं। ज़रूरी टेक्स्ट को बदलने के बाद एक बार जांच लें।',
                )),
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _c,
              minLines: 5,
              maxLines: 10,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: tr(context, t('Kruti Dev text', 'कृतिदेव टेक्स्ट')),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: Text(tr(context, t('Paste', 'पेस्ट'))),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _c.text.isEmpty ? null : () => setState(_c.clear),
                  child: Text(tr(context, t('Clear', 'साफ़ करें'))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr(context, t('Unicode Hindi', 'यूनिकोड हिंदी')),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(out, style: const TextStyle(fontSize: 18, height: 1.5)),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: out.isEmpty ? null : () => _copy(out),
              icon: const Icon(Icons.copy_rounded),
              label: Text(tr(context, t('Copy result', 'नतीजा कॉपी करें'))),
            ),
          ],
        ),
      ),
    );
  }
}
