/// Text that carries its own translations, e.g.
/// `LText({'en': 'Percentage', 'hi': 'प्रतिशत'})`.
/// Used for tool content (many small labels). Adding a language later means
/// adding one more key to the maps; missing languages fall back to English.
class LText {
  final Map<String, String> _values;
  const LText(this._values);

  String of(String languageCode) =>
      _values[languageCode] ?? _values['en'] ?? '';

  @override
  String toString() => of('en');
}

/// Short helper: `t('Percentage', 'प्रतिशत')`.
LText t(String en, String hi) => LText({'en': en, 'hi': hi});
