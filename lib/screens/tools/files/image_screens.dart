import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/files/file_helpers.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/tools/files/image_ops.dart';
import '../../../core/tools/files/pdf_ops.dart';
import '../../../core/tools/files/photo_check.dart';
import 'crop_frame.dart';
import 'file_ui.dart';

final LText _errSize = t('Please enter a valid size.', 'कृपया सही आकार दर्ज करें।');

/// Pick a picture and keep a rotation-corrected working copy for cropping.
mixin WorkingImagePicker<T extends StatefulWidget> on State<T>, ToolRunner<T> {
  PickedFile? pickedFile;
  WorkingImage? working;

  Future<void> pickWorking() async {
    final f = await pickFiles(extensions: imageExtensions);
    if (f.isEmpty || !mounted) return;
    setState(() {
      busy = true;
      errorText = null;
      result = null;
    });
    try {
      final bytes = await f.first.readBytes();
      final w = await prepareWorkingImageAsync(bytes);
      if (w == null) throw const FormatException('unreadable');
      if (mounted) {
        setState(() {
          pickedFile = f.first;
          working = w;
        });
        onWorkingPicked();
      }
    } catch (e) {
      if (mounted) setState(() => errorText = describeError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Screens can react (e.g. reset a ratio).
  void onWorkingPicked() {}
}

({int x, int y, int w, int h}) _toPixels(Rect r, WorkingImage w) {
  final x = r.left.round().clamp(0, w.width - 1);
  final y = r.top.round().clamp(0, w.height - 1);
  final cw = r.width.round().clamp(1, w.width - x);
  final ch = r.height.round().clamp(1, w.height - y);
  return (x: x, y: y, w: cw, h: ch);
}

// ======================= Compress =======================

class ImageCompressScreen extends StatefulWidget {
  const ImageCompressScreen({super.key});

  @override
  State<ImageCompressScreen> createState() => _ImageCompressScreenState();
}

class _ImageCompressScreenState extends State<ImageCompressScreen> with ToolRunner {
  PickedFile? _file;
  ImageSize? _size;
  bool _byTarget = true;
  final TextEditingController _kb = TextEditingController(text: '100');
  double _quality = 70;

  @override
  void dispose() {
    _kb.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickFiles(extensions: imageExtensions);
    if (f.isEmpty || !mounted) return;
    final bytes = await f.first.readBytes();
    if (!mounted) return;
    setState(() {
      _file = f.first;
      _size = readImageSize(bytes);
      clearResult();
      if (_size == null) errorText = Tx.errUnreadable;
    });
  }

  Future<void> _compress() async {
    final kb = parseInt(_kb);
    if (_byTarget && (kb == null || kb < 1)) {
      setState(() => errorText = _errSize);
      return;
    }
    await runJob(() async {
      final file = _file!;
      final bytes = await file.readBytes();
      Uint8List out;
      var met = true;
      if (_byTarget) {
        final r = await prepareForUploadAsync(bytes, maxBytes: kb! * 1024);
        if (r == null) throw const FormatException('unreadable');
        out = r.bytes;
        met = r.metTarget;
      } else {
        final r = await reencodeAsync(bytes, png: false, quality: _quality.round());
        if (r == null) throw const FormatException('unreadable');
        out = r;
      }
      final saved = await writeOutput('${baseName(file.name)}_compressed.jpg', out);
      final pct = file.size == 0 ? 0 : ((1 - saved.size / file.size) * 100).round();
      return JobResult(
        [saved],
        info: [
          (Tx.before, formatBytes(file.size)),
          (Tx.after, formatBytes(saved.size)),
          (Tx.saving, '$pct%'),
        ],
        warnings: [
          if (!met)
            t(
              'The target size could not be reached without making the picture too small. Try a larger size.',
              'फ़ोटो को बहुत छोटा किए बिना लक्ष्य आकार नहीं मिल सका। बड़ा आकार चुनकर देखें।',
            ),
          if (saved.size >= file.size) Tx.notSmaller,
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: t('Compress Picture', 'फ़ोटो कंप्रेस करें'),
      children: [
        PickButton(label: Tx.chooseImage, icon: Icons.image_outlined, onPressed: busy ? null : _pick),
        if (_file != null) ...[
          const SizedBox(height: 12),
          PickedCard(
            file: _file!,
            icon: Icons.image_outlined,
            trailing: _size == null ? null : Text('${_size!.width}×${_size!.height}'),
          ),
          const SizedBox(height: 16),
          ChoiceRow<bool>(
            label: t('Compress by', 'कंप्रेस करें'),
            value: _byTarget,
            options: [
              (true, t('Target size', 'लक्ष्य आकार')),
              (false, t('Quality', 'क्वालिटी')),
            ],
            onChanged: (v) => setState(() {
              _byTarget = v;
              clearResult();
            }),
          ),
          if (_byTarget)
            NumField(controller: _kb, label: t('Maximum size', 'अधिकतम आकार'), suffix: 'KB')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tx(context, t('Quality', 'क्वालिटी'))}: ${_quality.round()}%'),
                Slider(
                  min: 10,
                  max: 95,
                  divisions: 17,
                  value: _quality,
                  onChanged: (v) => setState(() {
                    _quality = v;
                    clearResult();
                  }),
                ),
              ],
            ),
          NoteBox(
            icon: Icons.info_outline_rounded,
            text: tx(
              context,
              t(
                'The result is a JPG. Transparent areas become white.',
                'परिणाम JPG होगा। पारदर्शी हिस्से सफ़ेद हो जाएंगे।',
              ),
            ),
          ),
          const SizedBox(height: 14),
          ActionButton(
            label: t('Compress', 'कंप्रेस करें'),
            icon: Icons.compress_rounded,
            busy: busy,
            onPressed: _compress,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Resize =======================

class ImageResizeScreen extends StatefulWidget {
  const ImageResizeScreen({super.key});

  @override
  State<ImageResizeScreen> createState() => _ImageResizeScreenState();
}

class _ImageResizeScreenState extends State<ImageResizeScreen> with ToolRunner {
  PickedFile? _file;
  ImageSize? _size;
  bool _percent = false;
  bool _keepRatio = true;
  bool _png = false;
  final TextEditingController _w = TextEditingController();
  final TextEditingController _h = TextEditingController();
  final TextEditingController _p = TextEditingController(text: '50');

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickFiles(extensions: imageExtensions);
    if (f.isEmpty || !mounted) return;
    final bytes = await f.first.readBytes();
    if (!mounted) return;
    final size = readImageSize(bytes);
    setState(() {
      _file = f.first;
      _size = size;
      clearResult();
      if (size == null) {
        errorText = Tx.errUnreadable;
      } else {
        _w.text = '${size.width}';
        _h.text = '${size.height}';
      }
    });
  }

  void _widthChanged(String v) {
    final s = _size;
    final w = int.tryParse(v);
    if (_keepRatio && s != null && w != null) {
      _h.text = '${(w * s.height / s.width).round()}';
    }
    setState(clearResult);
  }

  void _heightChanged(String v) {
    final s = _size;
    final h = int.tryParse(v);
    if (_keepRatio && s != null && h != null) {
      _w.text = '${(h * s.width / s.height).round()}';
    }
    setState(clearResult);
  }

  Future<void> _resize() async {
    final s = _size!;
    int? w, h;
    if (_percent) {
      final p = parseDouble(_p);
      if (p == null || p <= 0 || p > 400) {
        setState(() => errorText = _errSize);
        return;
      }
      w = (s.width * p / 100).round();
      h = (s.height * p / 100).round();
    } else {
      w = parseInt(_w);
      h = parseInt(_h);
    }
    if (w == null || h == null || w < 1 || h < 1 || w > 8000 || h > 8000) {
      setState(() => errorText = _errSize);
      return;
    }
    final fw = w, fh = h;
    await runJob(() async {
      final file = _file!;
      final bytes = await file.readBytes();
      final out = await reencodeAsync(bytes, width: fw, height: fh, png: _png, quality: 92);
      if (out == null) throw const FormatException('unreadable');
      final saved = await writeOutput('${baseName(file.name)}_${fw}x$fh.${_png ? 'png' : 'jpg'}', out);
      return JobResult(
        [saved],
        info: [
          (t('New size', 'नया आकार'), '$fw × $fh px'),
          (Tx.fileSize, formatBytes(saved.size)),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _size;
    return ToolPage(
      title: t('Resize Picture', 'फ़ोटो रीसाइज़ करें'),
      children: [
        PickButton(label: Tx.chooseImage, icon: Icons.image_outlined, onPressed: busy ? null : _pick),
        if (_file != null && s != null) ...[
          const SizedBox(height: 12),
          PickedCard(file: _file!, icon: Icons.image_outlined, trailing: Text('${s.width}×${s.height}')),
          const SizedBox(height: 16),
          ChoiceRow<bool>(
            label: t('Resize by', 'रीसाइज़ करें'),
            value: _percent,
            options: [
              (false, t('Pixels', 'पिक्सल')),
              (true, t('Percent', 'प्रतिशत')),
            ],
            onChanged: (v) => setState(() {
              _percent = v;
              clearResult();
            }),
          ),
          if (_percent)
            NumField(controller: _p, label: t('Scale', 'स्केल'), suffix: '%', decimal: true, onChanged: (_) => setState(clearResult))
          else ...[
            NumField(controller: _w, label: t('Width', 'चौड़ाई'), suffix: 'px', onChanged: _widthChanged),
            NumField(controller: _h, label: t('Height', 'ऊंचाई'), suffix: 'px', onChanged: _heightChanged),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tx(context, t('Keep proportions', 'अनुपात बनाए रखें'))),
              value: _keepRatio,
              onChanged: (v) => setState(() => _keepRatio = v),
            ),
          ],
          ChoiceRow<bool>(
            label: t('Save as', 'इस रूप में सेव करें'),
            value: _png,
            options: [(false, Tx.jpg), (true, Tx.png)],
            onChanged: (v) => setState(() {
              _png = v;
              clearResult();
            }),
          ),
          ActionButton(
            label: t('Resize', 'रीसाइज़ करें'),
            icon: Icons.photo_size_select_large_rounded,
            busy: busy,
            onPressed: _resize,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Crop =======================

class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({super.key});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> with ToolRunner, WorkingImagePicker {
  final CropController _crop = CropController();
  double? _aspect; // null = same shape as the picture
  bool _png = false;

  double get _frameAspect {
    final w = working!;
    return _aspect ?? (w.width / w.height);
  }

  @override
  void onWorkingPicked() => setState(() => _aspect = null);

  Future<void> _doCrop() async {
    final w = working!;
    final region = _crop.region;
    if (region == null) return;
    final p = _toPixels(region, w);
    await runJob(() async {
      final out = await cropAsync(w.bytes, x: p.x, y: p.y, w: p.w, h: p.h, png: _png);
      if (out == null) throw const FormatException('unreadable');
      final saved = await writeOutput('${baseName(pickedFile!.name)}_cropped.${_png ? 'png' : 'jpg'}', out);
      return JobResult(
        [saved],
        info: [
          (t('Size', 'आकार'), '${p.w} × ${p.h} px'),
          (Tx.fileSize, formatBytes(saved.size)),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = working;
    return ToolPage(
      title: t('Crop Picture', 'फ़ोटो क्रॉप करें'),
      children: [
        PickButton(label: Tx.chooseImage, icon: Icons.image_outlined, onPressed: busy ? null : pickWorking),
        if (w != null) ...[
          const SizedBox(height: 16),
          ChoiceRow<double?>(
            label: t('Shape', 'आकार'),
            value: _aspect,
            options: [
              (null, t('Original', 'मूल')),
              (1.0, t('Square 1:1', 'वर्ग 1:1')),
              (3 / 4, t('3:4', '3:4')),
              (4 / 5, t('4:5', '4:5')),
              (4 / 3, t('4:3', '4:3')),
              (16 / 9, t('16:9', '16:9')),
            ],
            onChanged: (v) => setState(() {
              _aspect = v;
              clearResult();
            }),
          ),
          CropFrame(
            bytes: w.bytes,
            imageWidth: w.width,
            imageHeight: w.height,
            aspect: _frameAspect,
            controller: _crop,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tx(context, t('Drag to move, pinch to zoom.', 'खिसकाकर हिलाएं, पिंच करके ज़ूम करें।')),
              textAlign: TextAlign.center,
            ),
          ),
          ChoiceRow<bool>(
            label: t('Save as', 'इस रूप में सेव करें'),
            value: _png,
            options: [(false, Tx.jpg), (true, Tx.png)],
            onChanged: (v) => setState(() => _png = v),
          ),
          ActionButton(label: t('Crop', 'क्रॉप करें'), icon: Icons.crop_rounded, busy: busy, onPressed: _doCrop),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Photo / signature for forms =======================

class FormPictureScreen extends StatefulWidget {
  final bool signature;
  const FormPictureScreen({super.key, required this.signature});

  @override
  State<FormPictureScreen> createState() => _FormPictureScreenState();
}

class _FormPictureScreenState extends State<FormPictureScreen> with ToolRunner, WorkingImagePicker {
  final CropController _crop = CropController();
  final TextEditingController _w = TextEditingController();
  final TextEditingController _h = TextEditingController();
  final TextEditingController _kb = TextEditingController(text: '50');

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _kb.dispose();
    super.dispose();
  }

  double? get _aspect {
    final w = parseInt(_w), h = parseInt(_h);
    if (w == null || h == null || w < 1 || h < 1) return null;
    return w / h;
  }

  Future<void> _create() async {
    final w = parseInt(_w), h = parseInt(_h), kb = parseInt(_kb);
    if (kb == null || kb < 1 || (w != null && (w < 10 || w > 8000)) || (h != null && (h < 10 || h > 8000))) {
      setState(() => errorText = _errSize);
      return;
    }
    final work = working!;
    final both = w != null && h != null;
    final region = both ? _crop.region : null;
    final crop = region == null ? null : _toPixels(region, work);
    await runJob(() async {
      // 3% safety margin: some portals count 1 KB as 1000 bytes
      final r = await prepareForUploadAsync(
        work.bytes,
        maxBytes: (kb * 1024 * 0.97).floor(),
        crop: crop,
        width: w,
        height: h,
        exactSize: both,
      );
      if (r == null) throw const FormatException('unreadable');
      final name = widget.signature ? 'signature' : 'photo';
      final saved = await writeOutput('${name}_${r.width}x${r.height}.jpg', r.bytes);
      return JobResult(
        [saved],
        info: [
          (t('Size', 'आकार'), '${r.width} × ${r.height} px'),
          (Tx.fileSize, '${(saved.size / 1024).toStringAsFixed(1)} KB'),
        ],
        warnings: [
          if (!r.metTarget)
            t(
              'Could not reach the size limit without making the picture too small. Try a larger limit.',
              'तस्वीर को बहुत छोटा किए बिना आकार सीमा नहीं मिल सकी। बड़ी सीमा आज़माएं।',
            ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final work = working;
    final aspect = _aspect;
    final title = widget.signature
        ? t('Signature Resize', 'हस्ताक्षर रीसाइज़')
        : t('Photo Resize for Forms', 'फ़ॉर्म के लिए फ़ोटो रीसाइज़');
    return ToolPage(
      title: title,
      children: [
        NoteBox(
          icon: Icons.info_outline_rounded,
          text: tx(
            context,
            t(
              'Enter the size the form asks for (see the official notification). Leave width/height empty to keep the picture shape.',
              'फ़ॉर्म में मांगा गया आकार दर्ज करें (आधिकारिक अधिसूचना देखें)। चित्र का आकार बनाए रखने के लिए चौड़ाई/ऊंचाई खाली छोड़ें।',
            ),
          ),
        ),
        const SizedBox(height: 14),
        PickButton(label: Tx.chooseImage, icon: Icons.image_outlined, onPressed: busy ? null : pickWorking),
        if (work != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NumField(
                  controller: _w,
                  label: t('Width', 'चौड़ाई'),
                  suffix: 'px',
                  onChanged: (_) => setState(clearResult),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumField(
                  controller: _h,
                  label: t('Height', 'ऊंचाई'),
                  suffix: 'px',
                  onChanged: (_) => setState(clearResult),
                ),
              ),
            ],
          ),
          NumField(
            controller: _kb,
            label: t('Maximum file size', 'अधिकतम फ़ाइल आकार'),
            suffix: 'KB',
            onChanged: (_) => setState(clearResult),
          ),
          if (aspect != null) ...[
            CropFrame(
              bytes: work.bytes,
              imageWidth: work.width,
              imageHeight: work.height,
              aspect: aspect,
              controller: _crop,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tx(context, t('Drag to move, pinch to zoom.', 'खिसकाकर हिलाएं, पिंच करके ज़ूम करें।')),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(work.bytes, height: 200, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
          ActionButton(
            label: t('Create', 'बनाएं'),
            icon: Icons.photo_size_select_large_rounded,
            busy: busy,
            onPressed: _create,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Passport photo =======================

class _PassportSize {
  final LText label;
  final int w, h; // pixels at 300 dpi
  const _PassportSize(this.label, this.w, this.h);
}

final List<_PassportSize> _passportSizes = [
  _PassportSize(t('35 × 45 mm', '35 × 45 मिमी'), 413, 531),
  _PassportSize(t('2 × 2 inch', '2 × 2 इंच'), 600, 600),
  _PassportSize(t('25 × 35 mm', '25 × 35 मिमी'), 295, 413),
];

class PassportPhotoScreen extends StatefulWidget {
  const PassportPhotoScreen({super.key});

  @override
  State<PassportPhotoScreen> createState() => _PassportPhotoScreenState();
}

class _PassportPhotoScreenState extends State<PassportPhotoScreen> with ToolRunner, WorkingImagePicker {
  final CropController _crop = CropController();
  final TextEditingController _copies = TextEditingController(text: '6');
  int _size = 0;
  bool _a4 = false;

  @override
  void dispose() {
    _copies.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final copies = parseInt(_copies);
    if (copies == null || copies < 1 || copies > 100) {
      setState(() => errorText = _errSize);
      return;
    }
    final work = working!;
    final region = _crop.region;
    if (region == null) return;
    final p = _toPixels(region, work);
    final size = _passportSizes[_size];
    final sheetW = _a4 ? 2480 : 1200;
    final sheetH = _a4 ? 3508 : 1800;
    final ptW = _a4 ? 595.28 : 288.0;
    final ptH = _a4 ? 841.89 : 432.0;
    await runJob(() async {
      final built = await buildPassportAsync(
        work.bytes,
        x: p.x,
        y: p.y,
        w: p.w,
        h: p.h,
        photoW: size.w,
        photoH: size.h,
        sheetW: sheetW,
        sheetH: sheetH,
        copies: copies,
      );
      if (built == null) throw const FormatException('unreadable');
      final pdf = await jpegToSinglePagePdf(built.sheet, ptW, ptH);
      final files = [
        await writeOutput('passport_sheet.jpg', built.sheet),
        await writeOutput('passport_sheet.pdf', pdf),
        await writeOutput('passport_single.jpg', built.photo),
      ];
      return JobResult(
        files,
        info: [
          (t('Photo size', 'फ़ोटो का आकार'), '${size.w} × ${size.h} px'),
          (t('Copies on sheet', 'शीट पर कॉपी'), '${built.placed}'),
        ],
        warnings: [
          if (built.placed < copies)
            t(
              'Only ${built.placed} copies fit on this paper.',
              'इस कागज़ पर केवल ${built.placed} कॉपी आती हैं।',
            ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final work = working;
    final size = _passportSizes[_size];
    return ToolPage(
      title: t('Passport Photo Maker', 'पासपोर्ट फ़ोटो मेकर'),
      children: [
        NoteBox(
          icon: Icons.info_outline_rounded,
          text: tx(
            context,
            t(
              'Use a clear photo with a plain light background and the face looking straight. Print at 100% (actual size).',
              'साफ़ फ़ोटो लें जिसमें सादा हल्का बैकग्राउंड हो और चेहरा सीधा हो। 100% (वास्तविक आकार) पर प्रिंट करें।',
            ),
          ),
        ),
        const SizedBox(height: 14),
        PickButton(label: Tx.chooseImage, icon: Icons.image_outlined, onPressed: busy ? null : pickWorking),
        if (work != null) ...[
          const SizedBox(height: 16),
          ChoiceRow<int>(
            label: t('Photo size', 'फ़ोटो का आकार'),
            value: _size,
            options: [for (var i = 0; i < _passportSizes.length; i++) (i, _passportSizes[i].label)],
            onChanged: (v) => setState(() {
              _size = v;
              clearResult();
            }),
          ),
          CropFrame(
            bytes: work.bytes,
            imageWidth: work.width,
            imageHeight: work.height,
            aspect: size.w / size.h,
            controller: _crop,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              tx(context, t('Move and zoom so the face fills the frame.', 'चेहरा फ़्रेम में आए, इस तरह खिसकाएं और ज़ूम करें।')),
              textAlign: TextAlign.center,
            ),
          ),
          ChoiceRow<bool>(
            label: t('Print on', 'प्रिंट कागज़'),
            value: _a4,
            options: [
              (false, t('4 × 6 inch', '4 × 6 इंच')),
              (true, t('A4', 'A4')),
            ],
            onChanged: (v) => setState(() {
              _a4 = v;
              clearResult();
            }),
          ),
          NumField(controller: _copies, label: t('Number of copies', 'कॉपी की संख्या')),
          ActionButton(
            label: t('Create print sheet', 'प्रिंट शीट बनाएं'),
            icon: Icons.print_outlined,
            busy: busy,
            onPressed: _create,
          ),
        ],
        ...statusWidgets(context),
      ],
    );
  }
}

// ======================= Photo / signature checker =======================

class PhotoCheckerScreen extends StatefulWidget {
  const PhotoCheckerScreen({super.key});

  @override
  State<PhotoCheckerScreen> createState() => _PhotoCheckerScreenState();
}

class _PhotoCheckerScreenState extends State<PhotoCheckerScreen> with ToolRunner {
  PickedFile? _file;
  PhotoFacts? _facts;
  ImageFormat? _format; // null = JPG or PNG
  final TextEditingController _w = TextEditingController();
  final TextEditingController _h = TextEditingController();
  final TextEditingController _min = TextEditingController();
  final TextEditingController _max = TextEditingController();

  @override
  void dispose() {
    _w.dispose();
    _h.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickFiles(extensions: imageExtensions);
    if (f.isEmpty || !mounted) return;
    final bytes = await f.first.readBytes();
    if (!mounted) return;
    final size = readImageSize(bytes);
    setState(() {
      _file = f.first;
      errorText = size == null ? Tx.errUnreadable : null;
      _facts = size == null
          ? null
          : PhotoFacts(size.width, size.height, bytes.length, detectFormat(bytes));
    });
  }

  static LText _name(CheckKind k) => switch (k) {
        CheckKind.dimensions => t('Dimensions', 'आकार (पिक्सल)'),
        CheckKind.minSize => t('Minimum file size', 'न्यूनतम फ़ाइल आकार'),
        CheckKind.maxSize => t('Maximum file size', 'अधिकतम फ़ाइल आकार'),
        CheckKind.format => t('File type', 'फ़ाइल प्रकार'),
      };

  @override
  Widget build(BuildContext context) {
    final facts = _facts;
    final scheme = Theme.of(context).colorScheme;
    List<CheckItem> checks = const [];
    if (facts != null) {
      checks = checkPhoto(
        PhotoSpec(
          width: parseInt(_w),
          height: parseInt(_h),
          minKb: parseDouble(_min),
          maxKb: parseDouble(_max),
          format: _format,
        ),
        facts,
      );
    }
    final allOk = allChecksPass(checks);
    return ToolPage(
      title: t('Photo / Signature Checker', 'फ़ोटो / हस्ताक्षर जांचें'),
      children: [
        PickButton(label: Tx.chooseImage, icon: Icons.image_outlined, onPressed: _pick),
        ...statusWidgets(context),
        if (_file != null && facts != null) ...[
          const SizedBox(height: 12),
          PickedCard(file: _file!, icon: Icons.image_outlined, trailing: Text('${facts.width}×${facts.height}')),
          const SizedBox(height: 16),
          Text(
            tx(context, t('What does the form ask for? (leave empty if not mentioned)', 'फ़ॉर्म में क्या मांगा गया है? (न बताया हो तो खाली छोड़ें)')),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: NumField(controller: _w, label: t('Width', 'चौड़ाई'), suffix: 'px', onChanged: (_) => setState(() {})),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumField(controller: _h, label: t('Height', 'ऊंचाई'), suffix: 'px', onChanged: (_) => setState(() {})),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: NumField(
                  controller: _min,
                  label: t('Min size', 'न्यूनतम आकार'),
                  suffix: 'KB',
                  decimal: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumField(
                  controller: _max,
                  label: t('Max size', 'अधिकतम आकार'),
                  suffix: 'KB',
                  decimal: true,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          ChoiceRow<ImageFormat?>(
            label: t('File type', 'फ़ाइल प्रकार'),
            value: _format,
            options: [
              (null, t('Any (JPG/PNG)', 'कोई भी (JPG/PNG)')),
              (ImageFormat.jpeg, Tx.jpg),
              (ImageFormat.png, Tx.png),
            ],
            onChanged: (v) => setState(() => _format = v),
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: allOk ? scheme.primaryContainer : scheme.errorContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        allOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: allOk ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tx(
                            context,
                            allOk
                                ? t('All requirements are met', 'सभी शर्तें पूरी हैं')
                                : t('Some requirements are not met', 'कुछ शर्तें पूरी नहीं हैं'),
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: allOk ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final c in checks)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(c.ok ? Icons.check_rounded : Icons.close_rounded),
                      title: Text(tx(context, _name(c.kind))),
                      subtitle: Text('${c.actual}  •  ${c.required}'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
