/// Kruti Dev (old Hindi typing font) -> Unicode (Mangal) converter.
///
/// It handles the common letters, matras, half letters, "ि" and reph
/// re-ordering. Rare symbols are left unchanged, so check important text.

const String _virama = '्';
const String _reph = ''; // temporary marker for the Kruti "Z" (reph)

/// Longer keys first, so "vks" is read as "ओ" and not "अ" + "े".
final List<MapEntry<String, String>> _map = (() {
  final m = <String, String>{
    // vowels
    'vkS': 'औ', 'vks': 'ओ', 'vkW': 'ऑ', 'vk': 'आ', 'v': 'अ',
    'bZ': 'ई', 'b': 'इ', 'm': 'उ', 'Å': 'ऊ', ',s': 'ऐ', ',': 'ए', '_': 'ऋ',
    // full letters written as half letter + "k"
    '[k': 'ख', '?k': 'घ', '>k': 'झ', '.k': 'ण', 'Fk': 'थ', '/k': 'ध',
    '{k': 'क्ष', 'Hk': 'भ', "'k": 'श', '"k': 'ष',
    // matras
    'kS': 'ौ', 'ks': 'ो', 'kW': 'ॉ', 'k': 'ा', 'h': 'ी', 'q': 'ु', 'w': 'ू',
    's': 'े', 'S': 'ै', '`': 'ृ', 'a': 'ं', '¡': 'ँ', '%': 'ः', '~': _virama,
    'z': '${_virama}र', // rakar (प्र): virama + ra
    // full consonants
    'd': 'क', 'x': 'ग', '³': 'ङ', 'p': 'च', 'N': 'छ', 't': 'ज', '¥': 'ञ',
    'V': 'ट', 'B': 'ठ', 'M': 'ड', '<': 'ढ', 'r': 'त', 'n': 'द', 'u': 'न',
    'i': 'प', 'Q': 'फ', 'c': 'ब', 'e': 'म', ';': 'य', 'j': 'र', 'y': 'ल',
    'o': 'व', 'l': 'स', 'g': 'ह',
    // half letters
    'D': 'क$_virama', '[': 'ख$_virama', 'X': 'ग$_virama', '?': 'घ$_virama',
    'P': 'च$_virama', 'T': 'ज$_virama', '>': 'झ$_virama', 'U': 'न$_virama',
    'R': 'त$_virama', 'F': 'थ$_virama', '/': 'ध$_virama', 'C': 'ब$_virama',
    'H': 'भ$_virama', 'E': 'म$_virama', 'Y': 'ल$_virama', 'L': 'स$_virama',
    'O': 'व$_virama', 'I': 'प$_virama', '.': 'ण$_virama', "'": 'श$_virama',
    '"': 'ष$_virama',
    // special letters
    '{': 'क्ष$_virama', 'K': 'ज्ञ', '=': 'त्र', 'J': 'श्र', 'Z': _reph,
    // punctuation
    'A': '।',
  };
  final list = m.entries.toList()..sort((a, b) => b.key.length.compareTo(a.key.length));
  return list;
})();

final RegExp _cluster = RegExp('(?:[क-ह]$_virama)*[क-ह]');
final RegExp _chhotiI = RegExp('ि(${_cluster.pattern})');
final RegExp _repha = RegExp('(${_cluster.pattern}[ा-ौँंः]*)$_reph');

String krutiDevToUnicode(String input) {
  if (input.isEmpty) return input;
  final out = StringBuffer();
  var i = 0;
  // "f" is the Kruti "ि" (written before the letter).
  while (i < input.length) {
    var matched = false;
    if (input[i] == 'f') {
      out.write('ि');
      i++;
      continue;
    }
    for (final e in _map) {
      if (input.startsWith(e.key, i)) {
        out.write(e.value);
        i += e.key.length;
        matched = true;
        break;
      }
    }
    if (!matched) {
      out.write(input[i]);
      i++;
    }
  }
  var text = out.toString();
  // 1) "ि" is typed before the letter but belongs after it.
  text = text.replaceAllMapped(_chhotiI, (m) => '${m.group(1)}ि');
  // 2) Reph ("Z") is typed after the letter but belongs before it.
  text = text.replaceAllMapped(_repha, (m) => 'र$_virama${m.group(1)}');
  return text.replaceAll(_reph, '');
}
