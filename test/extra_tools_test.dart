import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/files/pdf_ops.dart';
import 'package:app/core/tools/kruti_dev.dart';
import 'package:app/core/tools/qr_payload.dart';
import 'package:app/core/tools/text_stats.dart';

void main() {
  group('Kruti Dev', () {
    test('common words', () {
      expect(krutiDevToUnicode('Hkkjr'), 'भारत');
      expect(krutiDevToUnicode('fgUnh'), 'हिन्दी');
      expect(krutiDevToUnicode('dk;Z'), 'कार्य');
      expect(krutiDevToUnicode('izse'), 'प्रेम');
      expect(krutiDevToUnicode('x`g'), 'गृह');
      expect(krutiDevToUnicode('Kku'), 'ज्ञान');
      expect(krutiDevToUnicode('fQj'), 'फिर');
      expect(krutiDevToUnicode('Hkkjr ljdkj'), 'भारत सरकार');
    });
    test('empty and plain text stay safe', () {
      expect(krutiDevToUnicode(''), '');
      expect(krutiDevToUnicode('123'), '123');
    });
  });

  group('text tools', () {
    test('counts', () {
      final s = analyseText('Hello world. This is SaralBook!');
      expect(s.words, 5);
      expect(s.sentences, 2);
      expect(analyseText('   ').words, 0);
    });
    test('clean-ups', () {
      expect(cleanSpaces('a   b \n\n  c  '), 'a b\nc');
      expect(removeDuplicateLines('a\nA\nb\na'), 'a\nb');
      expect(sortLines('b\na\nc'), 'a\nb\nc');
      expect(toTitleCase('hello big WORLD'), 'Hello Big World');
      expect(toSentenceCase('hello. how are you? fine'), 'Hello. How are you? Fine');
    });
  });

  group('QR payloads', () {
    test('wifi', () {
      expect(wifiPayload(ssid: 'Home', password: 'pass;word'), r'WIFI:T:WPA;S:Home;P:pass\;word;;');
      expect(wifiPayload(ssid: 'Cafe', security: 'nopass'), 'WIFI:T:nopass;S:Cafe;;');
    });
    test('upi', () {
      final u = upiPayload(upiId: 'abc@okbank', name: 'A B', amount: '10');
      expect(u.startsWith('upi://pay?pa=abc%40okbank'), isTrue);
      expect(u.contains('am=10'), isTrue);
      expect(isValidUpiId('abc@okbank'), isTrue);
      expect(isValidUpiId('abc'), isFalse);
    });
  });

  test('compress to a size: start step depends on how much smaller is wanted', () {
    expect(compressLadderStart(1000, 900), 0);
    expect(compressLadderStart(1000, 700), 1);
    expect(compressLadderStart(1000, 500), 2);
    expect(compressLadderStart(1000, 300), 3);
    expect(compressLadderStart(1000, 100), 4);
    expect(compressLadderStart(0, 100), 0);
    expect(kCompressLadder.length, greaterThan(compressLadderStart(1000, 1)));
  });
}
