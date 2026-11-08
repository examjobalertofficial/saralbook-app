import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/countdown_model.dart';
import 'package:app/core/tools/kruti_dev.dart';
import 'package:app/core/tools/notes_model.dart';
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

  group('countdown', () {
    final today = DateTime(2026, 11, 9, 23, 30);
    test('days left ignores the time of day', () {
      final i = CountdownItem(id: '1', title: 'SSC', date: DateTime(2026, 11, 19));
      expect(i.daysLeft(today), 10);
      expect(CountdownItem(id: '2', title: 'x', date: DateTime(2026, 11, 9)).daysLeft(today), 0);
      expect(CountdownItem(id: '3', title: 'x', date: DateTime(2026, 11, 8)).daysLeft(today), -1);
    });
    test('save and load, bad data ignored', () {
      final items = [CountdownItem(id: '1', title: 'A', date: DateTime(2027, 1, 5))];
      final back = decodeCountdowns(encodeCountdowns(items));
      expect(back.single.title, 'A');
      expect(back.single.date, DateTime(2027, 1, 5));
      expect(decodeCountdowns('not json'), isEmpty);
      expect(decodeCountdowns('[{"id":1}]'), isEmpty);
    });
    test('upcoming first, finished last', () {
      final a = CountdownItem(id: 'a', title: 'a', date: DateTime(2026, 12, 1));
      final b = CountdownItem(id: 'b', title: 'b', date: DateTime(2026, 11, 12));
      final c = CountdownItem(id: 'c', title: 'c', date: DateTime(2026, 10, 1));
      expect(sortCountdowns([a, c, b], today).map((e) => e.id).toList(), ['b', 'a', 'c']);
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

  test('notes lists survive bad data', () {
    final raw = encodeList([TodoItem(id: '1', text: 'Study', done: true).toMap()]);
    final back = decodeList<TodoItem>(raw, TodoItem.fromMap, kMaxTodos);
    expect(back.single.done, isTrue);
    expect(decodeList<TodoItem>('oops', TodoItem.fromMap, kMaxTodos), isEmpty);
  });
}
