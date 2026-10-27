import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/imagenote/note_render.dart';

void main() {
  test('the note text size follows the picture width and the chosen size', () {
    expect(noteFontSize(1000, 1), closeTo(1000 * kNoteFontFraction, 1e-9));
    expect(noteFontSize(1000, 1.4), greaterThan(noteFontSize(1000, 1)));
    expect(noteFontSize(1000, 0.7), lessThan(noteFontSize(1000, 1)));
    expect(noteFontSize(50, 0.7), 12.0); // never smaller than 12
  });

  test('default note style is bold black on white', () {
    const s = NoteStyle(lines: ['Name: A']);
    expect(s.bold, isTrue);
    expect(s.textColor, 0xFF000000);
    expect(s.stripColor, 0xFFFFFFFF);
  });
}
