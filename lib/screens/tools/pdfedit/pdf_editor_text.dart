import '../../../core/l10n/ltext.dart';

/// Words used by the PDF Editor (English + Hindi).
class EdTx {
  static final title = t('PDF Editor', 'PDF एडिटर');
  static final intro = t(
    'Open a PDF, then add text, pen or highlighter marks, a signature, pictures or a white patch. '
        'Re-order, rotate or delete pages and add page numbers or a watermark. Works offline.',
    'PDF खोलें, फिर टेक्स्ट, पेन या हाइलाइटर, हस्ताक्षर, फ़ोटो या सफेद पट्टी जोड़ें। '
        'पेज आगे-पीछे, घुमाएं या हटाएं, और पेज नंबर या वॉटरमार्क लगाएं। ऑफ़लाइन चलता है।',
  );
  static final honest = t(
    'The saved PDF is made of page pictures: the original text is no longer selectable, and a white patch really removes what is below it.',
    'सेव की गई PDF पेज की फ़ोटो से बनती है: असली टेक्स्ट सेलेक्ट नहीं होगा, और सफेद पट्टी नीचे की चीज़ सच में हटा देती है।',
  );
  static final choose = t('Choose PDF', 'PDF चुनें');
  static final opening = t('Opening the PDF…', 'PDF खुल रही है…');
  static LText tooMany(int n, int max) => t(
        'This PDF has $n pages. The editor handles up to $max pages at a time. Use "Split PDF" first.',
        'इस PDF में $n पेज हैं। एडिटर एक बार में $max पेज तक चलाता है। पहले "PDF स्प्लिट" इस्तेमाल करें।',
      );

  // tools
  static final select = t('Move', 'हिलाएं');
  static final text = t('Text', 'टेक्स्ट');
  static final pen = t('Pen', 'पेन');
  static final highlight = t('Highlight', 'हाइलाइट');
  static final cover = t('White patch', 'सफेद पट्टी');
  static final signature = t('Signature', 'हस्ताक्षर');
  static final picture = t('Picture', 'फ़ोटो');
  static final undo = t('Undo', 'वापस');
  static final zoom = t('Zoom', 'ज़ूम');
  static final fit = t('Fit', 'पूरा');
  static final pagesBtn = t('Pages', 'पेज');
  static final save = t('Save', 'सेव');

  static final hintSelect = t('Tap an item to select it, then drag it.', 'किसी चीज़ पर टैप करके चुनें, फिर खींचें।');
  static final hintText = t('Tap on the page where the text should start.', 'पेज पर वहां टैप करें जहां से टेक्स्ट शुरू करना है।');
  static final hintPen = t('Draw with your finger.', 'उंगली से लिखें।');
  static final hintCover = t('Drag a box over what you want to hide.', 'जो छुपाना है उस पर बॉक्स खींचें।');
  static final hintZoom = t('Pinch to zoom, drag to move the view. Turn Zoom off to edit.', 'ज़ूम के लिए पिंच करें, दृश्य खींचें। एडिट के लिए ज़ूम बंद करें।');

  // selected item
  static final size = t('Size', 'आकार');
  static final colour = t('Colour', 'रंग');
  static final bold = t('Bold', 'मोटा');
  static final edit = t('Edit text', 'टेक्स्ट बदलें');
  static final delete = t('Delete', 'हटाएं');
  static final thin = t('Thin', 'पतला');
  static final medium = t('Medium', 'मध्यम');
  static final thick = t('Thick', 'मोटा');

  // text dialog
  static final typeText = t('Type the text', 'टेक्स्ट लिखें');
  static final add = t('Add', 'जोड़ें');
  static final ok = t('OK', 'ठीक है');
  static final cancel = t('Cancel', 'रद्द करें');

  // signature
  static final drawSignature = t('Draw your signature', 'अपना हस्ताक्षर बनाएं');
  static final clear = t('Clear', 'मिटाएं');
  static final use = t('Use', 'लगाएं');

  // pages screen
  static final pagesTitle = t('Pages', 'पेज');
  static final pagesHint = t(
    'Drag the handle to re-order. Rotate or delete a page with the buttons.',
    'क्रम बदलने के लिए हैंडल खींचें। बटन से पेज घुमाएं या हटाएं।',
  );
  static final page = t('Page', 'पेज');
  static final rotate = t('Rotate', 'घुमाएं');
  static final rotateBlocked = t(
    'Rotate a page before adding anything on it.',
    'पेज घुमाने का काम उस पर कुछ जोड़ने से पहले करें।',
  );
  static final done = t('Done', 'हो गया');

  // save dialog
  static final saveTitle = t('Save PDF', 'PDF सेव करें');
  static final quality = t('Quality', 'क्वालिटी');
  static final high = t('High', 'उच्च');
  static final standard = t('Standard', 'सामान्य');
  static final small = t('Small file', 'छोटी फ़ाइल');
  static final numbers = t('Page numbers', 'पेज नंबर');
  static final numNone = t('None', 'नहीं');
  static final numBottomCenter = t('Bottom middle', 'नीचे बीच में');
  static final numBottomRight = t('Bottom right', 'नीचे दाएं');
  static final numBottomLeft = t('Bottom left', 'नीचे बाएं');
  static final numTopRight = t('Top right', 'ऊपर दाएं');
  static final watermark = t('Watermark text (optional)', 'वॉटरमार्क टेक्स्ट (वैकल्पिक)');
  static final saving = t('Making the PDF…', 'PDF बन रही है…');
  static final leaveTitle = t('Leave the editor?', 'एडिटर से बाहर जाएं?');
  static final leaveBody = t('Your changes are not saved.', 'आपके बदलाव सेव नहीं हुए हैं।');
  static final leave = t('Leave', 'बाहर जाएं');
  static final stay = t('Stay', 'यहीं रहें');
  static final pickFailed = t('Could not add that picture.', 'वह फ़ोटो नहीं जोड़ी जा सकी।');
}
