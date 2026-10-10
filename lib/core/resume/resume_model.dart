import 'dart:convert';
import 'dart:typed_data';

String _s(Object? v, int max) {
  if (v is! String) return '';
  return v.length > max ? v.substring(0, max) : v;
}

class EducationEntry {
  String degree;
  String board;
  String year;
  String score;
  EducationEntry({this.degree = '', this.board = '', this.year = '', this.score = ''});

  bool get isEmpty => degree.trim().isEmpty && board.trim().isEmpty && year.trim().isEmpty && score.trim().isEmpty;

  Map<String, Object?> toJson() => {'degree': degree, 'board': board, 'year': year, 'score': score};

  static EducationEntry fromJson(Object? m) {
    final j = m is Map ? m : const {};
    return EducationEntry(degree: _s(j['degree'], 80), board: _s(j['board'], 80), year: _s(j['year'], 20), score: _s(j['score'], 20));
  }
}

class ExperienceEntry {
  String role;
  String company;
  String period;
  String details;
  ExperienceEntry({this.role = '', this.company = '', this.period = '', this.details = ''});

  bool get isEmpty => role.trim().isEmpty && company.trim().isEmpty && details.trim().isEmpty;

  Map<String, Object?> toJson() => {'role': role, 'company': company, 'period': period, 'details': details};

  static ExperienceEntry fromJson(Object? m) {
    final j = m is Map ? m : const {};
    return ExperienceEntry(
      role: _s(j['role'], 80),
      company: _s(j['company'], 80),
      period: _s(j['period'], 40),
      details: _s(j['details'], 600),
    );
  }
}

/// The five looks (ids are stored in the draft).
const List<String> resumeTemplateIds = ['classic', 'modern', 'sidebar', 'strip', 'border'];

/// Theme colours people can pick (0xRRGGBB).
const List<int> resumeColors = [0x2C3E50, 0x1565C0, 0x00796B, 0x6A1B9A, 0xC62828, 0xEF6C00, 0x37474F, 0x000000];

const List<String> objectivePresets = [
  'To secure a challenging position in a reputable organization.',
  'Seeking a responsible job with opportunities for growth.',
];

/// Everything a resume needs. Plain data: saved on the phone as a draft.
class ResumeData {
  String fullName;
  String headline;
  String phone;
  String email;
  String address;
  String objective;
  List<EducationEntry> education;
  List<ExperienceEntry> experience;
  List<String> skills;
  String fatherName;
  String dob;
  String gender;
  String maritalStatus;
  String nationality;
  String languages;
  bool showDeclaration;
  String declarationPlace;
  String declarationDate;
  String templateId;
  int colorValue;

  /// Small square JPEG of the person (optional).
  Uint8List? photo;

  ResumeData({
    this.fullName = '',
    this.headline = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.objective = '',
    List<EducationEntry>? education,
    List<ExperienceEntry>? experience,
    List<String>? skills,
    this.fatherName = '',
    this.dob = '',
    this.gender = '',
    this.maritalStatus = '',
    this.nationality = '',
    this.languages = '',
    this.showDeclaration = true,
    this.declarationPlace = '',
    this.declarationDate = '',
    this.templateId = 'classic',
    this.colorValue = 0x2C3E50,
    this.photo,
  })  : education = education ??
            [
              EducationEntry(degree: 'High School'),
              EducationEntry(degree: 'Intermediate'),
              EducationEntry(degree: 'Graduation'),
            ],
        experience = experience ?? [],
        skills = skills ?? [];

  /// Education rows that have something written.
  List<EducationEntry> get filledEducation => [for (final e in education) if (!e.isEmpty && (e.board.trim().isNotEmpty || e.year.trim().isNotEmpty || e.score.trim().isNotEmpty)) e];

  List<ExperienceEntry> get filledExperience => [for (final e in experience) if (!e.isEmpty) e];

  List<String> get filledSkills => [for (final s in skills) if (s.trim().isNotEmpty) s.trim()];

  /// The 'personal details' that have a value, as (label, value).
  List<(String, String)> get personalRows => [
        if (fatherName.trim().isNotEmpty) ("Father's Name", fatherName.trim()),
        if (dob.trim().isNotEmpty) ('Date of Birth', dob.trim()),
        if (gender.trim().isNotEmpty) ('Gender', gender.trim()),
        if (maritalStatus.trim().isNotEmpty) ('Marital Status', maritalStatus.trim()),
        if (nationality.trim().isNotEmpty) ('Nationality', nationality.trim()),
        if (languages.trim().isNotEmpty) ('Languages', languages.trim()),
      ];

  /// A resume needs at least a name.
  bool get canBuild => fullName.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
        'fullName': fullName,
        'headline': headline,
        'phone': phone,
        'email': email,
        'address': address,
        'objective': objective,
        'education': [for (final e in education) e.toJson()],
        'experience': [for (final e in experience) e.toJson()],
        'skills': skills,
        'fatherName': fatherName,
        'dob': dob,
        'gender': gender,
        'maritalStatus': maritalStatus,
        'nationality': nationality,
        'languages': languages,
        'showDeclaration': showDeclaration,
        'declarationPlace': declarationPlace,
        'declarationDate': declarationDate,
        'templateId': templateId,
        'colorValue': colorValue,
        if (photo != null) 'photo': base64Encode(photo!),
      };

  String encode() => jsonEncode(toJson());

  /// Never throws: a damaged draft gives an empty resume.
  static ResumeData decode(String? text) {
    if (text == null || text.isEmpty) return ResumeData();
    try {
      final j = jsonDecode(text);
      if (j is! Map) return ResumeData();
      Uint8List? photo;
      final p = j['photo'];
      if (p is String && p.isNotEmpty && p.length < 400000) {
        try {
          photo = base64Decode(p);
        } catch (_) {
          photo = null;
        }
      }
      final tpl = j['templateId'];
      final color = j['colorValue'];
      return ResumeData(
        fullName: _s(j['fullName'], 80),
        headline: _s(j['headline'], 100),
        phone: _s(j['phone'], 30),
        email: _s(j['email'], 100),
        address: _s(j['address'], 200),
        objective: _s(j['objective'], 500),
        education: j['education'] is List ? [for (final e in (j['education'] as List).take(10)) EducationEntry.fromJson(e)] : null,
        experience: j['experience'] is List ? [for (final e in (j['experience'] as List).take(10)) ExperienceEntry.fromJson(e)] : null,
        skills: j['skills'] is List ? [for (final e in (j['skills'] as List).take(40)) if (e is String) _s(e, 40)] : null,
        fatherName: _s(j['fatherName'], 80),
        dob: _s(j['dob'], 30),
        gender: _s(j['gender'], 20),
        maritalStatus: _s(j['maritalStatus'], 20),
        nationality: _s(j['nationality'], 40),
        languages: _s(j['languages'], 100),
        showDeclaration: j['showDeclaration'] != false,
        declarationPlace: _s(j['declarationPlace'], 60),
        declarationDate: _s(j['declarationDate'], 30),
        templateId: tpl is String && resumeTemplateIds.contains(tpl) ? tpl : 'classic',
        colorValue: color is int && color >= 0 && color <= 0xFFFFFF ? color : 0x2C3E50,
        photo: photo,
      );
    } catch (_) {
      return ResumeData();
    }
  }
}
