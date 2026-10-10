import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:app/core/expense/pdf_report.dart';
import 'package:app/core/resume/resume_model.dart';
import 'package:app/core/resume/resume_pdf.dart';

ByteData _font(String name) => ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync());

ResumeData sample(String template) => ResumeData(
      fullName: 'Asha Verma / आशा वर्मा',
      headline: 'Fresher',
      phone: '9999999999',
      email: 'asha@example.com',
      address: 'Lucknow, Uttar Pradesh',
      objective: objectivePresets.first,
      education: [
        EducationEntry(degree: 'High School', board: 'UP Board', year: '2018', score: '82%'),
        EducationEntry(degree: 'Graduation', board: 'Lucknow University', year: '2023', score: '71%'),
        EducationEntry(degree: 'Empty row'),
      ],
      experience: [ExperienceEntry(role: 'Intern', company: 'ABC Ltd', period: '2023', details: 'Data entry and filing')],
      skills: ['MS Office', 'Typing', 'हिंदी टाइपिंग'],
      fatherName: 'R. Verma',
      dob: '01/01/2002',
      gender: 'Female',
      declarationPlace: 'Lucknow',
      declarationDate: '10/10/2026',
      templateId: template,
      photo: Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 40))),
    );

void main() {
  final fonts = PdfFontData(
    regular: _font('NotoSans-Regular.ttf'),
    bold: _font('NotoSans-Bold.ttf'),
    devanagari: _font('NotoSansDevanagari-Regular.ttf'),
  );

  group('ResumeData', () {
    test('draft survives a round trip', () {
      final back = ResumeData.decode(sample('modern').encode());
      expect(back.fullName, contains('Asha'));
      expect(back.templateId, 'modern');
      expect(back.education.length, 3);
      expect(back.filledEducation.length, 2, reason: 'rows with only a degree name are left out');
      expect(back.skills, contains('Typing'));
      expect(back.photo, isNotNull);
    });
    test('damaged drafts give an empty resume', () {
      expect(ResumeData.decode('not json').canBuild, isFalse);
      expect(ResumeData.decode(null).canBuild, isFalse);
      expect(ResumeData.decode('{"templateId":"zzz","colorValue":-5}').templateId, 'classic');
    });
    test('a name is needed', () {
      expect(ResumeData().canBuild, isFalse);
      expect(ResumeData(fullName: 'A').canBuild, isTrue);
    });
  });

  group('PDF', () {
    for (final id in resumeTemplateIds) {
      test('template $id makes a PDF', () async {
        final bytes = await buildResumePdf(sample(id), fonts);
        expect(bytes.length, greaterThan(2000));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      });
    }
    test('works with almost nothing filled in', () async {
      for (final id in resumeTemplateIds) {
        final bytes = await buildResumePdf(ResumeData(fullName: 'Only Name', templateId: id, showDeclaration: false), fonts);
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      }
    });
  });
}
