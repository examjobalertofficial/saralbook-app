import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/screens/tools/tool_catalog.dart';
import 'package:app/screens/tools/tool_style.dart';

void main() {
  test('a tool always gets the same colour', () {
    expect(toolAccent('percentage'), toolAccent('percentage'));
    expect(toolAccents.contains(toolAccent('resume_maker')), isTrue);
  });

  test('the colours are spread over the tools (not all the same)', () {
    final used = {for (final e in toolCatalog) toolAccent(e.id)};
    expect(used.length, greaterThanOrEqualTo(5));
  });

  test('card tint is a soft version of the accent', () {
    const surface = Color(0xFFFFFFFF);
    final tint = toolCardTint(const Color(0xFF3F6FD8), surface, dark: false);
    expect(tint, isNot(surface));
  });
}
