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
