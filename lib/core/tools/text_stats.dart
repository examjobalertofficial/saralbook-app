/// Counts and clean-ups for the Text Tools screen.
class TextStats {
  final int words;
  final int characters;
  final int charactersNoSpaces;
  final int sentences;
  final int lines;
  final int readingSeconds;

  const TextStats({
    required this.words,
    required this.characters,
    required this.charactersNoSpaces,
    required this.sentences,
    required this.lines,
    required this.readingSeconds,
  });
}

TextStats analyseText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const TextStats(
      words: 0, characters: 0, charactersNoSpaces: 0, sentences: 0, lines: 0, readingSeconds: 0,
    );
  }
  final words = trimmed.split(RegExp(r'\s+')).length;
  final chars = text.runes.length;
  final noSpaces = text.replaceAll(RegExp(r'\s'), '').runes.length;
  final sentences = RegExp(r'[^.!?।]+[.!?।]*').allMatches(trimmed).where((m) => m.group(0)!.trim().isNotEmpty).length;
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).length;
  // About 200 words a minute.
  final seconds = (words * 60 / 200).ceil();
  return TextStats(
    words: words,
    characters: chars,
    charactersNoSpaces: noSpaces,
    sentences: sentences,
    lines: lines,
    readingSeconds: seconds,
  );
}

String toTitleCase(String s) => s.toLowerCase().replaceAllMapped(
      RegExp(r"(^|[\s\-(\[\x22])([a-z])"),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );

String toSentenceCase(String s) {
  final lower = s.toLowerCase();
  return lower.replaceAllMapped(
    RegExp(r'(^\s*|[.!?]\s+|\n\s*)([a-z])'),
    (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
  );
}

/// Several spaces -> one, trims every line, and drops empty lines.
String cleanSpaces(String s) {
  final lines = s
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
      .where((l) => l.isNotEmpty);
  return lines.join('\n');
}

String removeDuplicateLines(String s) {
  final seen = <String>{};
  final out = <String>[];
  for (final line in s.split('\n')) {
    final key = line.trim().toLowerCase();
    if (key.isEmpty) continue;
    if (seen.add(key)) out.add(line.trim());
  }
  return out.join('\n');
}

String sortLines(String s) {
  final lines = s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return lines.join('\n');
}
