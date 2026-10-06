import 'dart:math' as math;

final math.Random _rng = math.Random.secure();

/// New unique id made on the phone (works offline, never repeats in practice).
/// Example: `lq3x9k2a_7fz1qk`
String newId() {
  final time = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final tail = List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
  return '${time}_$tail';
}

/// Stable text fingerprint (FNV-1a). Unlike `String.hashCode`, the result is
/// identical on every phone and every run, so the same page always gets the
/// same favourite id (no duplicates when syncing).
String stableHash(String input) {
  var h = 0x811c9dc5;
  for (final unit in input.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(36);
}
