import 'package:flutter/material.dart';

import '../../core/l10n/ltext.dart';
import '../../core/tools/calc_model.dart';
import '../../core/tools/calculators.dart';
import 'calc_tool_screen.dart';
import '../expense/currency_screens.dart';
import 'files/image_screens.dart';
import 'files/pdf_screens.dart';
import 'pomodoro_screen.dart';
import 'stopwatch_screen.dart';
import 'tool_entry.dart';

export 'tool_entry.dart';

/// Every offline tool in the app. To add a tool: add it here (or to
/// calculators.dart for a calculator).
final List<ToolEntry> toolCatalog = [
  for (final c in allCalcTools)
    ToolEntry(
      id: c.id,
      title: c.title,
      description: c.description,
      icon: c.icon,
      category: c.category,
      keywords: c.keywords,
      builder: (context) => CalcToolScreen(tool: c),
    ),
  ToolEntry(
    id: 'currency_converter',
    title: t('Currency Converter', 'मुद्रा कन्वर्टर'),
    description: t('Live rates, works offline with saved rates', 'लाइव दरें, सेव की गई दरों से ऑफ़लाइन भी चलता है'),
    icon: Icons.currency_exchange_rounded,
    category: ToolCategory.examCalc,
    keywords: const ['currency', 'dollar', 'usd', 'euro', 'exchange', 'rupee', 'forex'],
    builder: (context) => const CurrencyScreen(),
  ),
  // ---------------- PDF & image tools (offline) ----------------
  ToolEntry(
    id: 'pdf_viewer',
    title: t('PDF Viewer', 'PDF व्यूअर'),
    description: t('Open and read PDF files', 'PDF फ़ाइलें खोलें और पढ़ें'),
    icon: Icons.picture_as_pdf_outlined,
    category: ToolCategory.files,
    keywords: const ['pdf', 'open', 'read', 'view'],
    builder: (context) => const PdfViewerScreen(),
  ),
  ToolEntry(
    id: 'pdf_merge',
    title: t('Merge PDF', 'PDF मर्ज करें'),
    description: t('Combine several PDFs into one', 'कई PDF को एक में जोड़ें'),
    icon: Icons.merge_type_rounded,
    category: ToolCategory.files,
    keywords: const ['pdf', 'combine', 'join'],
    builder: (context) => const PdfMergeScreen(),
  ),
  ToolEntry(
    id: 'pdf_split',
    title: t('Split PDF', 'PDF स्प्लिट करें'),
    description: t('Extract pages or split into files', 'पेज निकालें या फ़ाइलों में बांटें'),
    icon: Icons.call_split_rounded,
    category: ToolCategory.files,
    keywords: const ['pdf', 'extract', 'pages', 'separate'],
    builder: (context) => const PdfSplitScreen(),
  ),
  ToolEntry(
    id: 'pdf_compress',
    title: t('Compress PDF', 'PDF कंप्रेस करें'),
    description: t('Make a PDF smaller', 'PDF का आकार छोटा करें'),
    icon: Icons.compress_rounded,
    category: ToolCategory.files,
    keywords: const ['pdf', 'reduce', 'size', 'smaller', 'kb', 'mb'],
    builder: (context) => const PdfCompressScreen(),
  ),
  ToolEntry(
    id: 'images_to_pdf',
    title: t('Pictures to PDF', 'फ़ोटो से PDF'),
    description: t('Turn pictures into one PDF', 'फ़ोटो को एक PDF में बदलें'),
    icon: Icons.photo_library_outlined,
    category: ToolCategory.files,
    keywords: const ['image', 'jpg', 'png', 'photo', 'convert', 'scan'],
    builder: (context) => const ImagesToPdfScreen(),
  ),
  ToolEntry(
    id: 'pdf_to_images',
    title: t('PDF to Pictures', 'PDF से फ़ोटो'),
    description: t('Save PDF pages as JPG or PNG', 'PDF पेज को JPG या PNG में सेव करें'),
    icon: Icons.image_search_rounded,
    category: ToolCategory.files,
    keywords: const ['pdf', 'jpg', 'png', 'convert', 'page'],
    builder: (context) => const PdfToImagesScreen(),
  ),
  ToolEntry(
    id: 'pdf_pages',
    title: t('PDF Page Counter', 'PDF पेज काउंटर'),
    description: t('Count pages and see page size', 'पेज गिनें और पेज का आकार देखें'),
    icon: Icons.format_list_numbered_rounded,
    category: ToolCategory.files,
    keywords: const ['pdf', 'count', 'pages'],
    builder: (context) => const PdfPageCounterScreen(),
  ),
  ToolEntry(
    id: 'image_compress',
    title: t('Compress Picture', 'फ़ोटो कंप्रेस करें'),
    description: t('Reduce a picture to a size in KB', 'फ़ोटो को KB में तय आकार तक घटाएं'),
    icon: Icons.photo_size_select_small_rounded,
    category: ToolCategory.files,
    keywords: const ['jpg', 'png', 'image', 'kb', 'reduce', 'size', 'compress'],
    builder: (context) => const ImageCompressScreen(),
  ),
  ToolEntry(
    id: 'image_resize',
    title: t('Resize Picture', 'फ़ोटो रीसाइज़ करें'),
    description: t('Change width and height', 'चौड़ाई और ऊंचाई बदलें'),
    icon: Icons.photo_size_select_large_rounded,
    category: ToolCategory.files,
    keywords: const ['image', 'pixels', 'width', 'height', 'resize'],
    builder: (context) => const ImageResizeScreen(),
  ),
  ToolEntry(
    id: 'image_crop',
    title: t('Crop Picture', 'फ़ोटो क्रॉप करें'),
    description: t('Cut a picture to a shape', 'फ़ोटो को तय आकार में काटें'),
    icon: Icons.crop_rounded,
    category: ToolCategory.files,
    keywords: const ['image', 'cut', 'crop'],
    builder: (context) => const ImageCropScreen(),
  ),
  ToolEntry(
    id: 'passport_photo',
    title: t('Passport Photo Maker', 'पासपोर्ट फ़ोटो मेकर'),
    description: t('Crop and make a print sheet', 'क्रॉप करें और प्रिंट शीट बनाएं'),
    icon: Icons.portrait_rounded,
    category: ToolCategory.files,
    keywords: const ['passport', 'photo', 'print', 'stamp size', 'id'],
    builder: (context) => const PassportPhotoScreen(),
  ),
  ToolEntry(
    id: 'photo_resize',
    title: t('Photo Resize for Forms', 'फ़ॉर्म के लिए फ़ोटो रीसाइज़'),
    description: t('Exact pixels and KB for online forms', 'ऑनलाइन फ़ॉर्म के लिए सही पिक्सल और KB'),
    icon: Icons.account_box_outlined,
    category: ToolCategory.examJob,
    keywords: const ['photo', 'form', 'application', 'upload', 'kb', 'ssc', 'rrb', 'resize'],
    builder: (context) => const FormPictureScreen(signature: false),
  ),
  ToolEntry(
    id: 'signature_resize',
    title: t('Signature Resize', 'हस्ताक्षर रीसाइज़'),
    description: t('Exact pixels and KB for signatures', 'हस्ताक्षर के लिए सही पिक्सल और KB'),
    icon: Icons.draw_outlined,
    category: ToolCategory.examJob,
    keywords: const ['signature', 'sign', 'form', 'upload', 'kb', 'resize'],
    builder: (context) => const FormPictureScreen(signature: true),
  ),
  ToolEntry(
    id: 'photo_checker',
    title: t('Photo / Signature Checker', 'फ़ोटो / हस्ताक्षर जांचें'),
    description: t('Check size, pixels and type before upload', 'अपलोड से पहले आकार, पिक्सल और प्रकार जांचें'),
    icon: Icons.verified_outlined,
    category: ToolCategory.examJob,
    keywords: const ['photo', 'signature', 'check', 'requirement', 'upload', 'form'],
    builder: (context) => const PhotoCheckerScreen(),
  ),
  ToolEntry(
    id: 'stopwatch',
    title: t('Stopwatch', 'स्टॉपवॉच'),
    description: t('Time yourself with laps', 'लैप के साथ समय नापें'),
    icon: Icons.timer_outlined,
    category: ToolCategory.student,
    keywords: const ['timer', 'lap'],
    builder: (context) => const StopwatchScreen(),
  ),
  ToolEntry(
    id: 'pomodoro',
    title: t('Pomodoro Timer', 'पोमोडोरो टाइमर'),
    description: t('25-minute focus sessions with breaks', 'ब्रेक के साथ 25 मिनट के फ़ोकस सेशन'),
    icon: Icons.local_cafe_outlined,
    category: ToolCategory.student,
    keywords: const ['focus', 'study', 'break'],
    builder: (context) => const PomodoroScreen(),
  ),
];
