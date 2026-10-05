import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/tools/calc_model.dart';
import 'package:app/screens/tools/tool_catalog.dart';

void main() {
  test('every tool has a unique id and both languages', () {
    final ids = toolCatalog.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final e in toolCatalog) {
      expect(e.title.of('en'), isNotEmpty, reason: e.id);
      expect(e.title.of('hi'), isNotEmpty, reason: e.id);
      expect(e.description.of('hi'), isNotEmpty, reason: e.id);
    }
  });

  test('every category has tools, including the PDF & image tools', () {
    for (final c in ToolCategory.values) {
      expect(toolCatalog.where((e) => e.category == c), isNotEmpty, reason: '$c');
    }
    for (final id in [
      'pdf_viewer', 'pdf_merge', 'pdf_split', 'pdf_compress', 'images_to_pdf',
      'pdf_to_images', 'pdf_pages', 'image_compress', 'image_resize', 'image_crop',
      'passport_photo', 'photo_resize', 'signature_resize', 'photo_checker',
    ]) {
      expect(toolCatalog.any((e) => e.id == id), isTrue, reason: id);
    }
  });
}
