import 'package:flutter/material.dart';

/// Bright accent colours for the tool cards. Colours only: no pictures, so the
/// app does not get any bigger.
const List<Color> toolAccents = [
  Color(0xFF3F6FD8), // blue
  Color(0xFFE8590C), // orange
  Color(0xFF2F9E44), // green
  Color(0xFF7048E8), // violet
  Color(0xFFD6336C), // pink
  Color(0xFF0C8599), // teal
  Color(0xFFE67700), // amber
  Color(0xFFC92A2A), // red
];

/// The same tool always gets the same colour (it only depends on its id).
Color toolAccent(String id) {
  var h = 7;
  for (final u in id.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return toolAccents[h % toolAccents.length];
}

/// Soft card background: the accent colour faded into the surface colour.
Color toolCardTint(Color accent, Color surface, {required bool dark}) =>
    Color.alphaBlend(accent.withAlpha(dark ? 44 : 30), surface);
