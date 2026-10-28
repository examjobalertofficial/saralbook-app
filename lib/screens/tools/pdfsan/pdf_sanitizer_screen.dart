import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_helpers.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/pdfsan/pdf_sanitize.dart';
import '../../../core/pdfsan/pdf_scan.dart';
import '../../../core/tools/files/pdf_ops.dart' show pdfSummary;
import '../files/file_ui.dart';
import '../scanner/scan_extra_screens.dart' show ScanPdfPreviewScreen;

/// Words used by the PDF Sanitizer (English + Hindi).
class SanTx {
  static final title = t('PDF Sanitizer', 'PDF सैनिटाइज़र');
  static final intro = t(
    'Check what is hidden inside a PDF (author, software, scripts, attached files, links, comments) and remove it before you share or upload the file.',
    'PDF के अंदर छुपी चीज़ें (लेखक, सॉफ्टवेयर, स्क्रिप्ट, जुड़ी फ़ाइलें, लिंक, कमेंट) देखें और फ़ाइल शेयर या अपलोड करने से पहले हटाएं।',
  );
  static final privacy = t(
    'Works fully on your phone: no internet, no sign-in, nothing is uploaded or sent anywhere.',
    'पूरी तरह आपके फ़ोन पर चलता है: इंटरनेट नहीं, साइन-इन नहीं, कुछ भी अपलोड या कहीं भेजा नहीं जाता।',
  );
  static final choose = t('Choose PDF', 'PDF चुनें');
  static final change = t('Change PDF', 'दूसरी PDF चुनें');
  static final checking = t('Checking the file…', 'फ़ाइल जांची जा रही है…');
  static final tooBig = t(
    'This file is bigger than 100 MB. Please use "Split PDF" or "Compress PDF" first.',
    'यह फ़ाइल 100 MB से बड़ी है। पहले "PDF स्प्लिट" या "PDF कंप्रेस" इस्तेमाल करें।',
  );
  static final passwordNote = t(
    'This PDF is protected. Its contents cannot be checked here, and cleaning needs the password.',
    'यह PDF सुरक्षित है। इसके अंदर की जांच यहां नहीं हो सकती और सफाई के लिए पासवर्ड चाहिए।',
  );

  // report
  static final beforeTitle = t('What is inside', 'अंदर क्या है');
  static final afterTitle = t('After cleaning', 'सफाई के बाद');
  static final riskLow = t('Nothing hidden found', 'कुछ छुपा नहीं मिला');
  static final riskMedium = t('Some hidden data', 'कुछ छुपी जानकारी');
  static final riskHigh = t('Risky items found', 'जोखिम वाली चीज़ें मिलीं');
  static final found = t('Found', 'मिला');
  static final packedNote = t(
    'Some parts of this file are packed tightly, so this quick check may miss items inside them. "Maximum safe" removes everything for sure.',
    'इस फ़ाइल के कुछ हिस्से कसकर पैक हैं, इसलिए यह जल्दी जांच उनके अंदर की चीज़ें छोड़ सकती है। "सबसे सुरक्षित" हर चीज़ पक्का हटा देता है।',
  );
  static final details = t('Document details', 'दस्तावेज़ की जानकारी');

  static LText finding(PdfFinding f) => switch (f) {
        PdfFinding.javascript => t('Scripts (JavaScript)', 'स्क्रिप्ट (JavaScript)'),
        PdfFinding.launch => t('Commands that can start other programs', 'दूसरे प्रोग्राम चलाने वाले कमांड'),
        PdfFinding.embeddedFile => t('Hidden attached files', 'छुपी हुई जुड़ी फ़ाइलें'),
        PdfFinding.richMedia => t('Embedded video or sound', 'अंदर जुड़ा वीडियो या आवाज़'),
        PdfFinding.autoActions => t('Actions that run when the file opens', 'खुलते ही चलने वाली क्रियाएं'),
        PdfFinding.formSubmit => t('Form data sending', 'फ़ॉर्म डेटा भेजने की क्रिया'),
        PdfFinding.forms => t('Fillable form fields', 'भरने वाले फ़ॉर्म फ़ील्ड'),
        PdfFinding.links => t('Web or file links', 'वेब या फ़ाइल लिंक'),
        PdfFinding.comments => t('Comments and mark-up', 'कमेंट और मार्कअप'),
        PdfFinding.metadata => t('Document details (author, software…)', 'दस्तावेज़ की जानकारी (लेखक, सॉफ्टवेयर…)'),
        PdfFinding.xmp => t('Extra hidden details (XMP)', 'अतिरिक्त छुपी जानकारी (XMP)'),
        PdfFinding.encrypted => t('Protected with a password', 'पासवर्ड से सुरक्षित'),
        PdfFinding.compressedParts => t('Tightly packed parts', 'कसकर पैक हिस्से'),
      };

  static LText infoKey(String key) => switch (key) {
        'Author' => t('Author', 'लेखक'),
        'Creator' => t('Made with', 'बनाने वाला ऐप'),
        'Producer' => t('Software', 'सॉफ्टवेयर'),
        'Title' => t('Title', 'शीर्षक'),
        'Subject' => t('Subject', 'विषय'),
        'Keywords' => t('Keywords', 'कीवर्ड'),
        _ => t(key, key),
      };

  // choices
  static final method = t('How to clean', 'कैसे साफ़ करें');
  static final standard = t('Standard clean', 'सामान्य सफाई');
  static final flatten = t('Maximum safe', 'सबसे सुरक्षित');
  static final standardHelp = t(
    'Rebuilds the PDF as a new file. Removes author and software details, start-up actions and attached files. Text stays selectable. Some page links or comments may remain; the check after cleaning shows what is left.',
    'PDF को नई फ़ाइल के रूप में दोबारा बनाता है। लेखक व सॉफ्टवेयर की जानकारी, शुरू होते ही चलने वाली क्रियाएं और जुड़ी फ़ाइलें हटती हैं। टेक्स्ट सेलेक्ट हो सकता है। कुछ पेज-लिंक या कमेंट बच सकते हैं; सफाई के बाद की जांच दिखाती है कि क्या बचा।',
  );
  static final flattenHelp = t(
    'Turns every page into a picture and builds a new PDF from the pictures. Removes everything: scripts, files, links, forms, comments, hidden text and details. Text can no longer be selected and the file may be bigger.',
    'हर पेज को फ़ोटो बनाकर उनसे नई PDF बनाता है। सब कुछ हट जाता है: स्क्रिप्ट, फ़ाइलें, लिंक, फ़ॉर्म, कमेंट, छुपा टेक्स्ट और जानकारी। टेक्स्ट सेलेक्ट नहीं हो सकेगा और फ़ाइल बड़ी हो सकती है।',
  );
  static final picture = t('Picture quality', 'फ़ोटो की क्वालिटी');
  static final small = t('Small file', 'छोटी फ़ाइल');
  static final normal = t('Standard', 'सामान्य');
  static final sharp = t('Sharp', 'साफ़');
  static final clean = t('Clean PDF', 'PDF साफ़ करें');
  static final pagesLabel = t('Pages', 'पेज');
  static final before = t('Size before', 'पहले का आकार');
  static final preview = t('Preview cleaned PDF', 'साफ़ की गई PDF देखें');
  static final stillRisky = t(
    'Risky items are still found in the cleaned file. Use "Maximum safe" to remove everything.',
    'साफ़ की गई फ़ाइल में अब भी जोखिम वाली चीज़ें मिलीं। सब कुछ हटाने के लिए "सबसे सुरक्षित" चुनें।',
  );
  static final stillSome = t(
    'Some page links or comments remain. Use "Maximum safe" if you need them gone too.',
    'कुछ पेज-लिंक या कमेंट बचे हैं। इन्हें भी हटाना हो तो "सबसे सुरक्षित" चुनें।',
  );
}

enum _Method { standard, flatten }

enum _Quality { small, normal, sharp }

class PdfSanitizerScreen extends StatefulWidget {
  const PdfSanitizerScreen({super.key});

  @override
  State<PdfSanitizerScreen> createState() => _PdfSanitizerScreenState();
}

class _PdfSanitizerScreenState extends State<PdfSanitizerScreen> with ToolRunner<PdfSanitizerScreen> {
  static const int _maxBytes = 100 * 1024 * 1024;

  PickedFile? _file;
  PdfScanReport? _before;
  PdfScanReport? _after;
  bool _scanning = false;
  _Method _method = _Method.standard;
  _Quality _quality = _Quality.normal;

  (int, int) get _flattenSettings => switch (_quality) {
        _Quality.small => (110, 70),
        _Quality.normal => (150, 82),
        _Quality.sharp => (200, 90),
      };

  Future<void> _pick() async {
    if (busy || _scanning) return;
    final files = await pickFiles(extensions: pdfExtensions);
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    setState(() {
      _file = null;
      _before = null;
      _after = null;
      result = null;
      errorText = null;
    });
    if (f.size > _maxBytes) {
      setState(() => errorText = SanTx.tooBig);
      return;
    }
    setState(() {
      _file = f;
      _scanning = true;
    });
    try {
      final report = await scanPdfFile(f.path);
      if (!mounted) return;
      setState(() => _before = report);
    } catch (e) {
      if (mounted) setState(() => errorText = describeError(e));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _clean() async {
    final f = _file;
    if (f == null) return;
    setState(() => _after = null);
    await runJob(() async {
      final Uint8List data;
      if (_method == _Method.standard) {
        data = await cleanStandard(f.path, onProgress: reportProgress);
      } else {
        final s = _flattenSettings;
        data = await cleanFlatten(f.path, dpi: s.$1, quality: s.$2, onProgress: reportProgress);
      }
      final out = await writeOutput('${baseName(f.name)}_clean.pdf', data);
      final after = await scanPdfFile(out.path);
      if (mounted) setState(() => _after = after);
      final summary = await pdfPagesOf(out.path);
      return JobResult(
        [out],
        info: [
          (SanTx.before, formatBytes(f.size)),
          (Tx.fileSize, formatBytes(out.size)),
          if (summary != null) (SanTx.pagesLabel, '$summary'),
        ],
        warnings: [
          if (after.risk == PdfRisk.high) SanTx.stillRisky,
          if (after.risk != PdfRisk.high &&
              _method == _Method.standard &&
              (after.has(PdfFinding.links) || after.has(PdfFinding.comments)))
            SanTx.stillSome,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = _file;
    final before = _before;
    final after = _after;
    return ToolPage(
      title: SanTx.title,
      children: [
        Text(tx(context, SanTx.intro), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        NoteBox(icon: Icons.shield_outlined, text: tx(context, SanTx.privacy)),
        const SizedBox(height: 16),
        if (file == null)
          PickButton(label: SanTx.choose, icon: Icons.picture_as_pdf_rounded, onPressed: (busy || _scanning) ? null : _pick)
        else ...[
          PickedCard(
            file: file,
            icon: Icons.picture_as_pdf_rounded,
            trailing: TextButton(
              onPressed: (busy || _scanning) ? null : _pick,
              child: Text(tx(context, SanTx.change)),
            ),
          ),
        ],
        if (_scanning)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 10),
                Text(tx(context, SanTx.checking)),
              ],
            ),
          ),
        if (before != null) ...[
          const SizedBox(height: 16),
          _ReportCard(title: SanTx.beforeTitle, report: before),
          const SizedBox(height: 18),
          ChoiceRow<_Method>(
            label: SanTx.method,
            options: [(_Method.standard, SanTx.standard), (_Method.flatten, SanTx.flatten)],
            value: _method,
            onChanged: (v) => setState(() {
              _method = v;
              result = null;
              _after = null;
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              tx(context, _method == _Method.standard ? SanTx.standardHelp : SanTx.flattenHelp),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          if (_method == _Method.flatten)
            ChoiceRow<_Quality>(
              label: SanTx.picture,
              options: [(_Quality.small, SanTx.small), (_Quality.normal, SanTx.normal), (_Quality.sharp, SanTx.sharp)],
              value: _quality,
              onChanged: (v) => setState(() {
                _quality = v;
                result = null;
                _after = null;
              }),
            ),
          ActionButton(
            label: SanTx.clean,
            icon: Icons.cleaning_services_rounded,
            busy: busy,
            enabled: !_scanning && !before.has(PdfFinding.encrypted),
            onPressed: _clean,
          ),
          if (before.has(PdfFinding.encrypted))
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: NoteBox(icon: Icons.lock_outline_rounded, text: tx(context, SanTx.passwordNote)),
            ),
        ],
        ...statusWidgets(context),
        if (after != null && result != null) ...[
          const SizedBox(height: 14),
          _ReportCard(title: SanTx.afterTitle, report: after),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => ScanPdfPreviewScreen(file: result!.files.first)),
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: Text(tx(context, SanTx.preview)),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ],
    );
  }
}

/// The list of hidden things found in a file, with a risk label.
class _ReportCard extends StatelessWidget {
  final LText title;
  final PdfScanReport report;
  const _ReportCard({required this.title, required this.report});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final risk = report.risk;
    final (Color bg, Color fg, IconData icon, LText label) = switch (risk) {
      PdfRisk.low => (const Color(0xFFE6F4EA), const Color(0xFF1E6B34), Icons.verified_user_rounded, SanTx.riskLow),
      PdfRisk.medium => (const Color(0xFFFFF4DB), const Color(0xFF8A5A00), Icons.info_outline_rounded, SanTx.riskMedium),
      PdfRisk.high => (const Color(0xFFFDE7E7), const Color(0xFFA32121), Icons.warning_amber_rounded, SanTx.riskHigh),
    };
    final shown = report.shown;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tx(context, title), style: Theme.of(context).textTheme.titleSmall)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 5),
                      Text(tx(context, label), style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            if (shown.isNotEmpty) const SizedBox(height: 10),
            for (final f in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PdfScanReport.isHigh(f) ? Icons.error_rounded : Icons.circle,
                      size: PdfScanReport.isHigh(f) ? 16 : 8,
                      color: PdfScanReport.isHigh(f) ? const Color(0xFFD32F2F) : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tx(context, SanTx.finding(f)))),
                    if (f == PdfFinding.links || f == PdfFinding.comments)
                      Text('${report.count(f)}', style: const TextStyle(fontWeight: FontWeight.w700))
                    else
                      Text(tx(context, SanTx.found), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
            if (report.info.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tx(context, SanTx.details), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 2),
              for (final e in report.info.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text('${tx(context, SanTx.infoKey(e.key))}: ${e.value}', style: const TextStyle(fontSize: 13)),
                ),
            ],
            if (report.has(PdfFinding.compressedParts) || report.has(PdfFinding.encrypted)) ...[
              const SizedBox(height: 8),
              Text(
                tx(context, report.has(PdfFinding.encrypted) ? SanTx.passwordNote : SanTx.packedNote),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Number of pages of a PDF (null if it cannot be read).
Future<int?> pdfPagesOf(String path) async {
  try {
    final size = await File(path).length();
    if (size == 0) return null;
    return (await pdfSummary(path)).pages;
  } catch (_) {
    return null;
  }
}
