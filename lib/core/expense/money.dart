/// Money is stored as whole "minor units" (paise for rupees) so that
/// adding many amounts never gives 0.1 + 0.2 style errors.

const int maxMinor = 100000000000; // 1,000,000,000.00

/// "1,234.5" -> 123450. Returns null for anything that is not a valid amount
/// (letters, negative, more than 2 decimals, zero, too big).
int? parseMinor(String input) {
  final s = input.replaceAll(',', '').trim();
  final m = RegExp(r'^(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final whole = int.parse(m.group(1)!);
  final fracText = (m.group(2) ?? '').padRight(2, '0');
  final minor = whole * 100 + int.parse(fracText.isEmpty ? '0' : fracText);
  if (minor < 1 || minor > maxMinor) return null;
  return minor;
}

/// 123450 -> "1234.50" (no symbol, no grouping): for editing fields.
String minorToPlain(int minor) {
  final neg = minor < 0;
  final a = minor.abs();
  return '${neg ? '-' : ''}${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

/// 123456789 -> "₹12,34,567.89" (Indian digit grouping).
String formatInr(int minor, {bool showSign = false}) {
  final neg = minor < 0;
  final a = minor.abs();
  final rupees = (a ~/ 100).toString();
  final paise = (a % 100).toString().padLeft(2, '0');
  String grouped;
  if (rupees.length <= 3) {
    grouped = rupees;
  } else {
    final last3 = rupees.substring(rupees.length - 3);
    var rest = rupees.substring(0, rupees.length - 3);
    final chunks = <String>[];
    while (rest.length > 2) {
      chunks.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) chunks.insert(0, rest);
    grouped = '${chunks.join(',')},$last3';
  }
  final sign = neg ? '-' : (showSign && a > 0 ? '+' : '');
  return '$sign₹$grouped.$paise';
}

/// Amount in another currency: "USD 1,250.00" (western grouping).
String formatForeign(int minor, String code) {
  final a = minor.abs();
  final whole = (a ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${minor < 0 ? '-' : ''}$code $buf.${(a % 100).toString().padLeft(2, '0')}';
}

/// Rupee amount rounded to a whole number of rupees, for big dashboard numbers.
String formatInrShort(int minor) {
  final neg = minor < 0;
  final r = (minor.abs() / 100).round();
  final full = formatInr(r * 100);
  return '${neg ? '-' : ''}${full.substring(0, full.length - 3)}';
}
