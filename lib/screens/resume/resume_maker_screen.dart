import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' show PdfViewer;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/expense/pdf_report.dart' show PdfFontData;
import '../../core/files/file_helpers.dart';
import '../../core/l10n/ltext.dart';
import '../../core/resume/resume_model.dart';
import '../../core/resume/resume_pdf.dart';
import '../../core/tools/files/image_ops.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';
import '../tools/files/file_ui.dart';

const String _draftKey = 'resume.draft.v1';

class ResumeMakerScreen extends StatefulWidget {
  const ResumeMakerScreen({super.key});

  @override
  State<ResumeMakerScreen> createState() => _ResumeMakerScreenState();
}

class _ResumeMakerScreenState extends State<ResumeMakerScreen> with ToolRunner<ResumeMakerScreen> {
  ResumeData _d = ResumeData();
  bool _loaded = false;
  Timer? _saveTimer;
  // changing a key makes a text field show a new value (preset / date picker)
  int _formVersion = 0;
  LText? _photoProblem;

  static final LText _title = t('Resume Maker', 'रिज़्यूमे मेकर');
  static final LText _note = t(
    'Your details are saved only on this phone. No sign-in needed.',
    'आपकी जानकारी सिर्फ़ इसी फ़ोन में सेव रहती है। साइन-इन की ज़रूरत नहीं।',
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadDraft());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_saveNow());
    _skillInput.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = ResumeData.decode(prefs.getString(_draftKey));
      if (mounted) {
        setState(() {
          _d = d;
          _loaded = true;
          _formVersion++;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _saveNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, _d.encode());
    } catch (_) {/* the draft is a convenience only */}
  }

  /// Call after every change.
  void _changed() {
    clearResult();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => unawaited(_saveNow()));
    setState(() {});
  }

  // ---------- small builders ----------

  Widget _field(
    String key,
    LText label,
    String Function() get,
    void Function(String) set, {
    int lines = 1,
    TextInputType? type,
    int max = 100,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        key: ValueKey('$key-$_formVersion'),
        initialValue: get(),
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        maxLength: max,
        keyboardType: type,
        textCapitalization: type == null ? TextCapitalization.sentences : TextCapitalization.none,
        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
        decoration: InputDecoration(labelText: tr(context, label), border: const OutlineInputBorder(), suffixIcon: suffix),
        onChanged: (v) {
          set(v);
          _changed();
        },
      ),
    );
  }

  Widget _section(IconData icon, LText title, List<Widget> children, {bool open = false}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: open,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(tr(context, title), style: const TextStyle(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ---------- photo ----------

  Future<void> _pickPhoto() async {
    final files = await pickFiles(extensions: imageExtensions);
    if (files.isEmpty) return;
    try {
      final bytes = await files.first.readBytes();
      final image = decodeOriented(bytes);
      if (image == null) {
        setState(() => _photoProblem = Tx.errUnreadable);
        return;
      }
      final side = image.width < image.height ? image.width : image.height;
      final square = cropRect(image, (image.width - side) ~/ 2, (image.height - side) ~/ 2, side, side);
      final small = resizeKeepRatio(square, width: 300);
      _d.photo = encodeJpeg(small, 85);
      _photoProblem = null;
      _changed();
    } catch (e) {
      setState(() => _photoProblem = describeError(e));
    }
  }

  // ---------- date ----------

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
    );
    if (picked == null) return;
    _d.dob = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    _formVersion++;
    _changed();
  }

  // ---------- build the PDF ----------

  Future<ByteData> _font(String name) => rootBundle.load('assets/fonts/$name');

  Future<void> _create() async {
    if (!_d.canBuild) return;
    await runJob(() async {
      final bytes = await buildResumePdf(
        _d,
        PdfFontData(
          regular: await _font('NotoSans-Regular.ttf'),
          bold: await _font('NotoSans-Bold.ttf'),
          devanagari: await _font('NotoSansDevanagari-Regular.ttf'),
        ),
      );
      final safe = _d.fullName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final out = await writeOutput('Resume_${safe.isEmpty ? 'me' : safe}.pdf', bytes);
      return JobResult([out], info: [(Tx.fileSize, formatBytes(out.size))]);
    });
  }

  void _preview(OutputFile f) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(tr(context, _title))),
          body: PdfViewer.file(f.path, key: ValueKey(f.path)),
        ),
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(ctx, t('Start a new resume?', 'नया रिज़्यूमे शुरू करें?'))),
        content: Text(tr(ctx, t('This clears everything you typed.', 'इससे आपका लिखा सब कुछ मिट जाएगा।'))),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr(ctx, t('Cancel', 'रद्द करें')))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr(ctx, t('Clear', 'मिटाएं')))),
        ],
      ),
    );
    if (ok == true) {
      _d = ResumeData();
      _formVersion++;
      _changed();
    }
  }

  // ---------- screen ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip: tr(context, t('Start new', 'नया शुरू करें')), icon: const Icon(Icons.restart_alt_rounded), onPressed: _clearAll),
        ],
      ),
      body: PageBody(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  NoteBox(icon: Icons.lock_outline_rounded, text: tr(context, _note)),
                  const SizedBox(height: 14),
                  _lookCard(scheme),
                  _basicSection(),
                  _objectiveSection(),
                  _educationSection(),
                  _experienceSection(),
                  _skillsSection(),
                  _personalSection(),
                  _declarationSection(),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _d.canBuild && !busy ? _create : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(tr(context, t('Create PDF', 'PDF बनाएं'))),
                  ),
                  if (!_d.canBuild)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(tr(context, t('Type your name to create the resume.', 'रिज़्यूमे बनाने के लिए अपना नाम लिखें।')), style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  ...statusWidgets(context),
                  if (result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _preview(result!.files.first),
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(tr(context, t('Preview', 'प्रीव्यू'))),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ---------- look: template, colour, photo ----------

  static final Map<String, LText> _templateNames = {
    'classic': t('Classic', 'क्लासिक'),
    'modern': t('Modern', 'मॉडर्न'),
    'sidebar': t('Sidebar', 'साइडबार'),
    'strip': t('Strip', 'स्ट्रिप'),
    'border': t('Clean', 'क्लीन'),
  };

  Widget _lookCard(ColorScheme scheme) {
    final color = Color(0xFF000000 | _d.colorValue);
    return _section(
      Icons.palette_outlined,
      t('Template, colour & photo', 'टेम्पलेट, रंग और फ़ोटो'),
      open: true,
      [
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final id in resumeTemplateIds)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      _d.templateId = id;
                      _changed();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: id == _d.templateId ? scheme.primary : scheme.outlineVariant, width: id == _d.templateId ? 3 : 1),
                          ),
                          child: _Thumb(id: id, color: color),
                        ),
                        const SizedBox(height: 4),
                        Text(tr(context, _templateNames[id]!), style: TextStyle(fontWeight: id == _d.templateId ? FontWeight.w700 : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final v in resumeColors)
              InkResponse(
                onTap: () {
                  _d.colorValue = v;
                  _changed();
                },
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: Color(0xFF000000 | v),
                  child: v == _d.colorValue ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.surfaceContainerHighest,
              backgroundImage: _d.photo == null ? null : MemoryImage(_d.photo!),
              child: _d.photo == null ? const Icon(Icons.person_outline_rounded) : null,
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: _pickPhoto, child: Text(tr(context, _d.photo == null ? t('Add photo (optional)', 'फ़ोटो जोड़ें (वैकल्पिक)') : Tx.change))),
            if (_d.photo != null)
              TextButton(
                onPressed: () {
                  _d.photo = null;
                  _changed();
                },
                child: Text(tr(context, Tx.remove)),
              ),
          ],
        ),
        if (_photoProblem != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr(context, _photoProblem!), style: TextStyle(color: scheme.error))),
      ],
    );
  }

  Widget _basicSection() => _section(Icons.badge_outlined, t('Contact details', 'संपर्क जानकारी'), open: true, [
        _field('name', t('Full name', 'पूरा नाम'), () => _d.fullName, (v) => _d.fullName = v, max: 80),
        _field('headline', t('Title (e.g. Fresher, Teacher)', 'पद (जैसे फ्रेशर, टीचर)'), () => _d.headline, (v) => _d.headline = v),
        _field('phone', t('Phone', 'फ़ोन'), () => _d.phone, (v) => _d.phone = v, type: TextInputType.phone, max: 30),
        _field('email', t('Email', 'ईमेल'), () => _d.email, (v) => _d.email = v, type: TextInputType.emailAddress),
        _field('address', t('Address', 'पता'), () => _d.address, (v) => _d.address = v, lines: 2, max: 200),
      ]);

  Widget _objectiveSection() => _section(Icons.flag_outlined, t('Career objective', 'करियर उद्देश्य'), [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in objectivePresets)
              ActionChip(
                label: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: () {
                  _d.objective = p;
                  _formVersion++;
                  _changed();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _field('objective', t('Objective', 'उद्देश्य'), () => _d.objective, (v) => _d.objective = v, lines: 3, max: 500),
      ]);

  Widget _educationSection() => _section(Icons.school_outlined, t('Education', 'शिक्षा'), [
        for (final e in _d.education)
          Card(
            key: ObjectKey(e),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Column(
                children: [
                  _field('edu-d-${identityHashCode(e)}', t('Class / Degree', 'कक्षा / डिग्री'), () => e.degree, (v) => e.degree = v, max: 80),
                  _field('edu-b-${identityHashCode(e)}', t('Board / University', 'बोर्ड / विश्वविद्यालय'), () => e.board, (v) => e.board = v, max: 80),
                  Row(
                    children: [
                      Expanded(child: _field('edu-y-${identityHashCode(e)}', t('Year', 'वर्ष'), () => e.year, (v) => e.year = v, type: TextInputType.number, max: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: _field('edu-s-${identityHashCode(e)}', t('Marks / %', 'अंक / %'), () => e.score, (v) => e.score = v, max: 20)),
                      IconButton(
                        tooltip: tr(context, Tx.remove),
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () {
                          _d.education.remove(e);
                          _changed();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_d.education.length < 10)
          TextButton.icon(
            onPressed: () {
              _d.education.add(EducationEntry());
              _changed();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tr(context, t('Add qualification', 'योग्यता जोड़ें'))),
          ),
      ]);

  Widget _experienceSection() => _section(Icons.work_outline_rounded, t('Experience', 'अनुभव'), [
        for (final e in _d.experience)
          Card(
            key: ObjectKey(e),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Column(
                children: [
                  _field('exp-r-${identityHashCode(e)}', t('Job title', 'पद'), () => e.role, (v) => e.role = v, max: 80),
                  _field('exp-c-${identityHashCode(e)}', t('Company / Place', 'कंपनी / स्थान'), () => e.company, (v) => e.company = v, max: 80),
                  _field('exp-p-${identityHashCode(e)}', t('Period (e.g. 2022 - 2024)', 'अवधि (जैसे 2022 - 2024)'), () => e.period, (v) => e.period = v, max: 40),
                  _field('exp-t-${identityHashCode(e)}', t('What you did', 'आपने क्या किया'), () => e.details, (v) => e.details = v, lines: 2, max: 600),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: tr(context, Tx.remove),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () {
                        _d.experience.remove(e);
                        _changed();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_d.experience.length < 10)
          TextButton.icon(
            onPressed: () {
              _d.experience.add(ExperienceEntry());
              _changed();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tr(context, t('Add experience', 'अनुभव जोड़ें'))),
          ),
      ]);

  final TextEditingController _skillInput = TextEditingController();

  void _addSkill() {
    final s = _skillInput.text.trim();
    if (s.isEmpty || _d.skills.length >= 40) return;
    if (!_d.skills.contains(s)) _d.skills.add(s.length > 40 ? s.substring(0, 40) : s);
    _skillInput.clear();
    _changed();
  }

  Widget _skillsSection() => _section(Icons.bolt_outlined, t('Skills', 'कौशल'), [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _skillInput,
                maxLength: 40,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: tr(context, t('Add a skill', 'कौशल जोड़ें')), border: const OutlineInputBorder()),
                onSubmitted: (_) => _addSkill(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _addSkill, icon: const Icon(Icons.add_rounded)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in _d.skills)
              InputChip(
                label: Text(s),
                onDeleted: () {
                  _d.skills.remove(s);
                  _changed();
                },
              ),
          ],
        ),
      ]);

  Widget _personalSection() => _section(Icons.person_outline_rounded, t('Personal details', 'व्यक्तिगत जानकारी'), [
        _field('father', t("Father's name", 'पिता का नाम'), () => _d.fatherName, (v) => _d.fatherName = v),
        _field(
          'dob',
          t('Date of birth', 'जन्म तिथि'),
          () => _d.dob,
          (v) => _d.dob = v,
          max: 30,
          suffix: IconButton(icon: const Icon(Icons.calendar_today_outlined), onPressed: _pickDob),
        ),
        Text(tr(context, t('Gender', 'लिंग')), style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final g in const [('Male', 'पुरुष'), ('Female', 'महिला'), ('Other', 'अन्य')])
              ChoiceChip(
                label: Text(tr(context, t(g.$1, g.$2))),
                selected: _d.gender == g.$1,
                onSelected: (_) {
                  _d.gender = _d.gender == g.$1 ? '' : g.$1;
                  _changed();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(tr(context, t('Marital status', 'वैवाहिक स्थिति')), style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final g in const [('Single', 'अविवाहित'), ('Married', 'विवाहित')])
              ChoiceChip(
                label: Text(tr(context, t(g.$1, g.$2))),
                selected: _d.maritalStatus == g.$1,
                onSelected: (_) {
                  _d.maritalStatus = _d.maritalStatus == g.$1 ? '' : g.$1;
                  _changed();
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _field('nation', t('Nationality', 'राष्ट्रीयता'), () => _d.nationality, (v) => _d.nationality = v, max: 40),
        _field('lang', t('Languages known', 'भाषाएं'), () => _d.languages, (v) => _d.languages = v),
      ]);

  Widget _declarationSection() => _section(Icons.draw_outlined, t('Declaration', 'घोषणा'), [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, t('Add declaration', 'घोषणा जोड़ें'))),
          subtitle: const Text('I hereby declare that the details furnished above are true.'),
          value: _d.showDeclaration,
          onChanged: (v) {
            _d.showDeclaration = v;
            _changed();
          },
        ),
        if (_d.showDeclaration) ...[
          _field('place', t('Place', 'स्थान'), () => _d.declarationPlace, (v) => _d.declarationPlace = v, max: 60),
          _field('ddate', t('Date', 'दिनांक'), () => _d.declarationDate, (v) => _d.declarationDate = v, max: 30),
        ],
      ]);
}

/// Tiny drawing of a template, so people can pick by looking.
class _Thumb extends StatelessWidget {
  final String id;
  final Color color;
  const _Thumb({required this.id, required this.color});

  Widget _line(double w, {Color? c, double h = 3}) => Container(width: w, height: h, margin: const EdgeInsets.only(bottom: 3), color: c ?? Colors.grey.shade400);

  @override
  Widget build(BuildContext context) {
    const w = 62.0;
    const h = 86.0;
    Widget body;
    switch (id) {
      case 'modern':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 22, color: color.withAlpha(50), padding: const EdgeInsets.all(4), child: Row(children: [CircleAvatar(radius: 7, backgroundColor: color), const SizedBox(width: 4), _line(22, c: color)])),
          const SizedBox(height: 5),
          for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.only(left: 4), child: _line(i.isEven ? 40 : 32)),
        ]);
      case 'sidebar':
        body = Row(children: [
          Container(width: 20, color: color),
          Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_line(26, c: color, h: 4), for (var i = 0; i < 6; i++) _line(i.isEven ? 30 : 24)]))),
        ]);
      case 'strip':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 20, color: color),
          const SizedBox(height: 5),
          for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.only(left: 4), child: _line(i.isEven ? 44 : 36, c: i == 0 || i == 3 ? color.withAlpha(120) : null)),
        ]);
      case 'border':
        body = Padding(padding: const EdgeInsets.all(4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _line(30, c: color, h: 5),
          for (var i = 0; i < 4; i++) Row(children: [Container(width: 2, height: 6, margin: const EdgeInsets.only(right: 3, bottom: 3), color: color), _line(30)]),
          _line(44),
          _line(38),
        ]));
      default:
        body = Padding(padding: const EdgeInsets.all(4), child: Column(children: [
          _line(34, c: color, h: 5),
          Container(height: 1.5, width: 50, color: color, margin: const EdgeInsets.only(bottom: 4)),
          for (var i = 0; i < 5; i++) _line(i.isEven ? 50 : 40),
        ]));
    }
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }
}
