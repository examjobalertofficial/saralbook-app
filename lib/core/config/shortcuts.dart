/// The 12 shortcut buttons on Home, in display order. The website settings can
/// hide any of them (see "Home shortcut buttons" in SaralBook App Config).
const List<String> kShortcutIds = [
  'latest',
  'admit_card',
  'answer_key',
  'result',
  'admission',
  'syllabus',
  'group_expense',
  'resume_maker',
  'doc_scanner',
  'photo_resize',
  'pdf_compress',
  'images_to_pdf',
];

/// `{"hidden": ["syllabus", "images_to_pdf"]}` -> the ids to hide.
/// Missing or wrong data hides nothing, so every button shows.
Set<String> parseHiddenShortcuts(Object? raw) {
  if (raw is! Map) return const {};
  final list = raw['hidden'];
  if (list is! List) return const {};
  return {
    for (final v in list)
      if (v is String && kShortcutIds.contains(v)) v,
  };
}
