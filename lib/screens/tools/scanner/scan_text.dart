import '../../../core/l10n/ltext.dart';

/// Words used by the document scanner (English + Hindi).
class ScanTx {
  static final title = t('Document Scanner', 'डॉक्यूमेंट स्कैनर');
  static final intro = t(
    'Scan with the camera or pick pictures. The page is straightened, cleaned and saved as a PDF. Works offline.',
    'कैमरे से स्कैन करें या फ़ोटो चुनें। पेज सीधा और साफ़ होकर PDF बन जाता है। ऑफ़लाइन चलता है।',
  );
  static final camera = t('Scan with camera', 'कैमरे से स्कैन करें');
  static final gallery = t('Pick from gallery', 'गैलरी से चुनें');
  static final addPage = t('Add page', 'पेज जोड़ें');
  static final noPages = t('No pages yet. Scan or pick a picture to begin.', 'अभी कोई पेज नहीं। शुरू करने के लिए स्कैन करें या फ़ोटो चुनें।');
  static final pagesTitle = t('Your pages', 'आपके पेज');
  static final edit = t('Edit', 'एडिट करें');
  static final moveEarlier = t('Move earlier', 'पहले ले जाएं');
  static final moveLater = t('Move later', 'बाद में ले जाएं');
  static final delete = t('Delete', 'हटाएं');
  static final fileName = t('File name', 'फ़ाइल का नाम');
  static final pageSize = t('PDF page', 'PDF पेज');
  static final a4 = t('A4 page', 'A4 पेज');
  static final sameAsScan = t('Same as scan', 'स्कैन जैसा');
  static final quality = t('Quality', 'क्वालिटी');
  static final high = t('High', 'उच्च');
  static final standard = t('Standard', 'सामान्य');
  static final small = t('Small file', 'छोटी फ़ाइल');
  static final createPdf = t('Create PDF', 'PDF बनाएं');
  static final savePictures = t('Save as pictures (JPG)', 'फ़ोटो (JPG) सेव करें');
  static final importing = t('Preparing the page…', 'पेज तैयार हो रहा है…');
  static final cameraFailed = t(
    'The camera could not be opened. Please allow the camera or use "Pick from gallery".',
    'कैमरा नहीं खुल सका। कृपया कैमरे की अनुमति दें या "गैलरी से चुनें" का उपयोग करें।',
  );
  static final notAPicture = t('Some files were not pictures and were skipped.', 'कुछ फ़ाइलें फ़ोटो नहीं थीं, उन्हें छोड़ दिया गया।');

  // my scans, re-order, preview
  static final myScans = t('My scans', 'मेरे स्कैन');
  static final savedNote = t(
    'Saved on this phone in "My scans" while you work.',
    'काम करते समय आपके फ़ोन में "मेरे स्कैन" में सेव रहता है।',
  );
  static final signInHint = t(
    'Sign in (More tab) to keep your scans in "My scans" and come back to them later. Scans are saved only on this phone.',
    'अपने स्कैन "मेरे स्कैन" में रखने और बाद में खोलने के लिए साइन इन करें (More टैब)। स्कैन सिर्फ इसी फ़ोन में सेव होते हैं।',
  );
  static final reorder = t('Re-order pages', 'पेज आगे-पीछे करें');
  static final reorderTitle = t('Re-order pages', 'पेज आगे-पीछे करें');
  static final reorderHint = t(
    'Press and drag the handle on the right to move a page.',
    'पेज हिलाने के लिए दाईं ओर का हैंडल दबाकर खींचें।',
  );
  static final newScan = t('New scan', 'नया स्कैन');
  static final newScanAsk = t(
    'Start a new scan? The pages on this screen will be cleared.',
    'नया स्कैन शुरू करें? इस स्क्रीन के पेज हट जाएंगे।',
  );
  static final newScanKept = t(
    'Start a new scan? The current one stays in "My scans".',
    'नया स्कैन शुरू करें? मौजूदा स्कैन "मेरे स्कैन" में रहेगा।',
  );
  static final yes = t('Start', 'शुरू करें');
  static final cancel = t('Cancel', 'रद्द करें');
  static final previewPdf = t('Preview PDF', 'PDF देखें');
  static final previewTitle = t('PDF preview', 'PDF प्रीव्यू');
  static final libraryEmpty = t('No saved scans yet.', 'अभी कोई सेव स्कैन नहीं।');
  static final libraryNote = t(
    'These scans are saved only on this phone, for your account. Nothing is uploaded.',
    'ये स्कैन सिर्फ इसी फ़ोन में आपके अकाउंट के लिए सेव हैं। कुछ भी अपलोड नहीं होता।',
  );
  static final openNow = t('Open now', 'अभी खुला है');
  static final deleteScanAsk = t('Delete this saved scan from the phone?', 'यह सेव स्कैन फ़ोन से हटाएं?');
  static final openFailed = t(
    'This saved scan could not be opened.',
    'यह सेव स्कैन खुल नहीं सका।',
  );
  static LText pagesCount(int n) => t('$n ${n == 1 ? 'page' : 'pages'}', '$n पेज');

  // editor
  static final editTitle = t('Edit page', 'पेज एडिट करें');
  static final done = t('Done', 'हो गया');
  static final tabCrop = t('Crop', 'क्रॉप');
  static final tabFilter = t('Filters', 'फ़िल्टर');
  static final tabAdjust = t('Adjust', 'एडजस्ट');
  static final autoDetect = t('Auto detect', 'अपने आप खोजें');
  static final fullPage = t('Full picture', 'पूरी फ़ोटो');
  static final dragCorners = t('Drag the corners to the edges of the page', 'कोनों को पेज के किनारों तक खींचें');
  static final brightness = t('Brightness', 'चमक');
  static final contrast = t('Contrast', 'कंट्रास्ट');
  static final rotateLeft = t('Rotate left', 'बाएं घुमाएं');
  static final rotateRight = t('Rotate right', 'दाएं घुमाएं');
  static final reset = t('Reset', 'रीसेट');

}


/// Names of the filters, in the same order as `ScanFilter.values`.
final List<LText> filterNames = [
  t('Original', 'ओरिजिनल'),
  t('Magic color', 'मैजिक कलर'),
  t('Black & white', 'ब्लैक & व्हाइट'),
  t('Gray', 'ग्रे'),
  t('Lighten', 'हल्का'),
  t('Sharp', 'शार्प'),
];
