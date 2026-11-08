import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import '../../../core/files/file_helpers.dart';
import '../../../core/l10n/ltext.dart';
import '../../../core/tools/qr_payload.dart';
import '../../../widgets/page_body.dart';
import '../../../widgets/tr.dart';

enum _QrKind { text, upi, wifi }

/// Makes QR codes for a link / text, a UPI payment or a WiFi login.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  _QrKind _kind = _QrKind.text;
  final _text = TextEditingController();
  final _upi = TextEditingController();
  final _upiName = TextEditingController();
  final _upiAmount = TextEditingController();
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  String _security = 'WPA';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_text, _upi, _upiName, _upiAmount, _ssid, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The text that goes inside the code, or '' when the form is not ready.
  String get _payload {
    switch (_kind) {
      case _QrKind.text:
        return _text.text.trim();
      case _QrKind.upi:
        return isValidUpiId(_upi.text)
            ? upiPayload(upiId: _upi.text, name: _upiName.text, amount: _upiAmount.text)
            : '';
      case _QrKind.wifi:
        return _ssid.text.trim().isEmpty
            ? ''
            : wifiPayload(ssid: _ssid.text.trim(), password: _pass.text, security: _security);
    }
  }

  static QrImage? _imageFor(String data) {
    if (data.isEmpty) return null;
    try {
      return QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M));
    } catch (_) {
      return null; // too much text for one code
    }
  }

  Future<Uint8List> _png(QrImage image) async {
    const scale = 12;
    const quiet = 4;
    final n = image.moduleCount;
    final size = ((n + quiet * 2) * scale).toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);
    final dark = Paint()..color = Colors.black;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (image.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH((x + quiet) * scale.toDouble(), (y + quiet) * scale.toDouble(), scale.toDouble(), scale.toDouble()),
            dark,
          );
        }
      }
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _share(QrImage image) async {
    setState(() => _busy = true);
    try {
      final bytes = await _png(image);
      final f = await writeOutput('SaralBook_QR.png', bytes);
      await shareOutputs([f]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, t('Could not save the QR code', 'QR कोड सेव नहीं हो सका')))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _payload;
    final image = _imageFor(data);
    Widget field(TextEditingController c, LText label, {TextInputType? type, bool obscure = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            keyboardType: type,
            obscureText: obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(border: const OutlineInputBorder(), labelText: tr(context, label)),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, t('QR Code Maker', 'QR कोड मेकर')))),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<_QrKind>(
              segments: [
                ButtonSegment(value: _QrKind.text, label: Text(tr(context, t('Link / Text', 'लिंक / टेक्स्ट')))),
                const ButtonSegment(value: _QrKind.upi, label: Text('UPI')),
                const ButtonSegment(value: _QrKind.wifi, label: Text('WiFi')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            if (_kind == _QrKind.text)
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: tr(context, t('Link or text', 'लिंक या टेक्स्ट')),
                ),
              ),
            if (_kind == _QrKind.upi) ...[
              field(_upi, t('UPI ID (name@bank)', 'UPI ID (name@bank)'), type: TextInputType.emailAddress),
              field(_upiName, t('Name (optional)', 'नाम (वैकल्पिक)')),
              field(_upiAmount, t('Amount (optional)', 'राशि (वैकल्पिक)'),
                  type: const TextInputType.numberWithOptions(decimal: true)),
            ],
            if (_kind == _QrKind.wifi) ...[
              field(_ssid, t('WiFi name', 'WiFi का नाम')),
              field(_pass, t('Password', 'पासवर्ड'), obscure: true),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in const [('WPA', 'WPA / WPA2'), ('WEP', 'WEP'), ('nopass', 'Open')])
                    ChoiceChip(
                      label: Text(o.$2),
                      selected: _security == o.$1,
                      onSelected: (_) => setState(() => _security = o.$1),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (image != null) ...[
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: CustomPaint(painter: _QrPainter(image)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : () => _share(image),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(tr(context, t('Share / Save picture', 'फ़ोटो शेयर / सेव करें'))),
              ),
            ] else
              Center(
                child: Text(
                  data.isEmpty
                      ? tr(context, t('Fill the details to see the QR code.', 'QR कोड देखने के लिए जानकारी भरें।'))
                      : tr(context, t('Too much text for one QR code.', 'एक QR कोड के लिए टेक्स्ट बहुत ज़्यादा है।')),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage image;
  _QrPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.width / n;
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (image.isDark(y, x)) {
          // A tiny overlap avoids hair-line gaps between squares.
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell + 0.4, cell + 0.4), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.image != image;
}
