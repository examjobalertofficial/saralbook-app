import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/files/file_helpers.dart';
import '../../../core/imagenote/note_render.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/tools/files/image_ops.dart';
import '../files/file_ui.dart';
import '../files/image_screens.dart' show WorkingImagePicker;

class NoteTx {
  static final title = t('Photo with Note', 'फ़ोटो के नीचे नोट');
  static final intro = t(
    'Add a line of text under a photo, for example your name and date of birth, as some forms ask. Works offline.',
    'फ़ोटो के नीचे नाम, जन्मतिथि जैसा नोट जोड़ें, जैसा कुछ फ़ॉर्म मांगते हैं। ऑफ़लाइन चलता है।',
  );
  static final camera = t('Take photo', 'फ़ोटो खींचें');
  static final noteLabel = t('Note under the photo (one line per row)', 'फ़ोटो के नीचे का नोट (हर पंक्ति अलग)');
  static final quick = t('Quick lines', 'तुरंत जोड़ें');
  static final textSize = t('Text size', 'अक्षरों का आकार');
  static final small = t('Small', 'छोटा');
  static final medium = t('Medium', 'मध्यम');
  static final large = t('Large', 'बड़ा');
  static final look = t('Colours', 'रंग');
  static final lookWhite = t('Black on white', 'सफेद पर काला');
  static final lookBlack = t('White on black', 'काले पर सफेद');
  static final lookYellow = t('Black on yellow', 'पीले पर काला');
  static final bold = t('Letters', 'अक्षर');
  static final boldYes = t('Bold', 'मोटे');
  static final boldNo = t('Normal', 'सामान्य');
  static final sizeLimit = t('File size limit', 'फ़ाइल आकार सीमा');
  static final noLimit = t('No limit', 'कोई सीमा नहीं');
  static final format = t('Format', 'फ़ॉर्मेट');
  static final width = t('Width in pixels (optional)', 'चौड़ाई पिक्सल में (वैकल्पिक)');
  static final create = t('Create picture', 'फ़ोटो बनाएं');
  static final needNote = t('Type the note first.', 'पहले नोट लिखें।');
  static final badWidth = t('Width must be between 100 and 6000.', 'चौड़ाई 100 से 6000 के बीच होनी चाहिए।');
  static final size = t('Size', 'आकार');
  static final preview = t('Preview', 'प्रीव्यू');
  static final limitMiss = t(
    'Could not reach the size limit without making the picture too small. Try a larger limit.',
    'तस्वीर को बहुत छोटा किए बिना आकार सीमा नहीं मिल सकी। बड़ी सीमा चुनें।',
  );
  static final cameraFailed = t(
    'The camera could not be opened. Please allow the camera or choose from the gallery.',
    'कैमरा नहीं खुल सका। कृपया कैमरे की अनुमति दें या गैलरी से चुनें।',
  );

  /// (button text, what it adds)
  static final List<(String, String)> quickLines = [
    ('Name', 'Name: '),
    ('D.O.B', 'D.O.B - DD-MM-YYYY'),
    ('D.O.P', 'D.O.P - DD-MM-YYYY'),
    ('Date', 'Date: DD-MM-YYYY'),
    ('Roll No', 'Roll No: '),
  ];
}

enum _Look { white, black, yellow }

class ImageNoteScreen extends StatefulWidget {
  const ImageNoteScreen({super.key});

  @override
  State<ImageNoteScreen> createState() => _ImageNoteScreenState();
}

class _ImageNoteScreenState extends State<ImageNoteScreen> with ToolRunner<ImageNoteScreen>, WorkingImagePicker<ImageNoteScreen> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _w = TextEditingController();
  double _scale = 1;
  _Look _look = _Look.white;
  bool _bold = true;
  int _kb = 0; // 0 = no limit
  bool _png = false;

  @override
  void dispose() {
    _text.dispose();
    _w.dispose();
    super.dispose();
  }

  Future<void> _camera() async {
    if (busy) return;
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 3200,
        maxHeight: 3200,
        imageQuality: 92,
      );
      if (shot == null) return;
      setState(() {
        busy = true;
        errorText = null;
        result = null;
      });
      final bytes = await shot.readAsBytes();
      final w = await prepareWorkingImageAsync(bytes);
      if (w == null) throw const FormatException('unreadable');
      if (mounted) setState(() => working = w);
    } catch (_) {
      if (mounted) setState(() => errorText = NoteTx.cameraFailed);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _addLine(String line) {
    final cur = _text.text;
    final next = cur.isEmpty || cur.endsWith('\n') ? '$cur$line' : '$cur\n$line';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    setState(() => result = null);
  }

  List<String> get _lines => [
        for (final l in _text.text.split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ];

  int get _textColor => _look == _Look.black ? 0xFFFFFFFF : 0xFF000000;
  int get _stripColor => switch (_look) {
        _Look.white => 0xFFFFFFFF,
        _Look.black => 0xFF000000,
        _Look.yellow => 0xFFFFF59D,
      };

  Future<void> _create() async {
    final lines = _lines;
    final work = working;
    if (work == null) return;
    if (lines.isEmpty) {
      setState(() => errorText = NoteTx.needNote);
      return;
    }
    final w = parseInt(_w);
    if (_w.text.trim().isNotEmpty && (w == null || w < 100 || w > 6000)) {
      setState(() => errorText = NoteTx.badWidth);
      return;
    }
    final style = NoteStyle(
      lines: lines,
      scale: _scale,
      textColor: _textColor,
      stripColor: _stripColor,
      bold: _bold,
    );
    await runJob(() async {
      final r = await buildPhotoWithNote(
        photo: work.bytes,
        style: style,
        width: w,
        // 3% safety margin: some portals count 1 KB as 1000 bytes
        maxBytes: _kb == 0 ? null : (_kb * 1024 * 0.97).floor(),
        png: _png && _kb == 0,
      );
      final saved = await writeOutput('photo_with_note.${r.png ? 'png' : 'jpg'}', r.bytes);
      return JobResult(
        [saved],
        info: [
          (NoteTx.size, '${r.width} × ${r.height} px'),
          (Tx.fileSize, '${(saved.size / 1024).toStringAsFixed(1)} KB'),
        ],
        warnings: [if (!r.metTarget) NoteTx.limitMiss],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final work = working;
    return ToolPage(
      title: NoteTx.title,
      children: [
        Text(tx(context, NoteTx.intro), style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : pickWorking,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(tx(context, work == null ? Tx.chooseImage : Tx.change)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _camera,
                icon: const Icon(Icons.photo_camera_rounded),
                label: Text(tx(context, NoteTx.camera)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
        if (work != null) ...[
          const SizedBox(height: 16),
          Text(tx(context, NoteTx.noteLabel), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => result = null),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Name: Rahul Kumar\nD.O.B - 12-05-2005',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(tx(context, NoteTx.quick), style: TextStyle(color: scheme.onSurfaceVariant)),
              for (final q in NoteTx.quickLines)
                ActionChip(label: Text(q.$1), onPressed: () => _addLine(q.$2)),
            ],
          ),
          const SizedBox(height: 14),
          Text(tx(context, NoteTx.preview), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          _Preview(
            photo: work.bytes,
            lines: _lines,
            scale: _scale,
            textColor: _textColor,
            stripColor: _stripColor,
            bold: _bold,
          ),
          const SizedBox(height: 16),
          ChoiceRow<double>(
            label: NoteTx.textSize,
            options: [(0.7, NoteTx.small), (1.0, NoteTx.medium), (1.4, NoteTx.large)],
            value: _scale,
            onChanged: (v) => setState(() {
              _scale = v;
              result = null;
            }),
          ),
          ChoiceRow<_Look>(
            label: NoteTx.look,
            options: [(_Look.white, NoteTx.lookWhite), (_Look.black, NoteTx.lookBlack), (_Look.yellow, NoteTx.lookYellow)],
            value: _look,
            onChanged: (v) => setState(() {
              _look = v;
              result = null;
            }),
          ),
          ChoiceRow<bool>(
            label: NoteTx.bold,
            options: [(true, NoteTx.boldYes), (false, NoteTx.boldNo)],
            value: _bold,
            onChanged: (v) => setState(() {
              _bold = v;
              result = null;
            }),
          ),
          ChoiceRow<int>(
            label: NoteTx.sizeLimit,
            options: [
              (0, NoteTx.noLimit),
              (50, t('50 KB', '50 KB')),
              (100, t('100 KB', '100 KB')),
              (200, t('200 KB', '200 KB')),
              (500, t('500 KB', '500 KB')),
            ],
            value: _kb,
            onChanged: (v) => setState(() {
              _kb = v;
              result = null;
            }),
          ),
          if (_kb == 0)
            ChoiceRow<bool>(
              label: NoteTx.format,
              options: [(false, t('JPG', 'JPG')), (true, t('PNG', 'PNG'))],
              value: _png,
              onChanged: (v) => setState(() {
                _png = v;
                result = null;
              }),
            ),
          TextField(
            controller: _w,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tx(context, NoteTx.width),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ActionButton(
            label: NoteTx.create,
            icon: Icons.check_rounded,
            busy: busy,
            onPressed: _create,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

/// The photo with the note, drawn with the same proportions as the saved picture.
class _Preview extends StatelessWidget {
  final Uint8List photo;
  final List<String> lines;
  final double scale;
  final int textColor;
  final int stripColor;
  final bool bold;
  const _Preview({
    required this.photo,
    required this.lines,
    required this.scale,
    required this.textColor,
    required this.stripColor,
    required this.bold,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final font = noteFontSize(w, scale);
        return Container(
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(
                photo,
                width: w,
                fit: BoxFit.fitWidth,
                cacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
                gaplessPlayback: true,
              ),
              Container(
                width: w,
                color: Color(stripColor),
                padding: EdgeInsets.all(font * 0.6),
                child: Text(
                  lines.isEmpty ? ' ' : lines.join('\n'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(textColor),
                    fontSize: font,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
