import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/l10n/ltext.dart';
import '../../widgets/page_body.dart';
import '../../widgets/tr.dart';

enum _Status { running, ok, failed }

class _Step {
  final LText title;
  final _Status status;
  final String detail;
  final LText? hint;
  const _Step(this.title, this.status, {this.detail = '', this.hint});
}

/// Step-by-step test of the cloud connection, with the exact reason when
/// something is wrong ("Could not sync" banner opens this screen).
class CloudCheckScreen extends StatefulWidget {
  const CloudCheckScreen({super.key});

  @override
  State<CloudCheckScreen> createState() => _CloudCheckScreenState();
}

class _CloudCheckScreenState extends State<CloudCheckScreen> {
  final List<_Step> _steps = [];
  bool _running = false;
  bool _started = false;

  static final LText _title = t('Cloud sync check', 'क्लाउड सिंक जांच');
  static final LText _signedIn = t('Signed in', 'साइन इन');
  static final LText _readProfile = t('Reach the server and read your folder', 'सर्वर से जुड़ना और आपका फ़ोल्डर पढ़ना');
  static final LText _readList = t('Read your expenses list', 'आपकी खर्च सूची पढ़ना');
  static final LText _writeTest = t('Save a test record', 'एक टेस्ट रिकॉर्ड सेव करना');
  static final LText _deleteTest = t('Remove the test record', 'टेस्ट रिकॉर्ड हटाना');
  static final LText _allGood = t('Everything works. Cloud sync is fine.', 'सब ठीक है। क्लाउड सिंक चल रहा है।');
  static final LText _problem = t('A step failed. Read the fix under it.', 'एक स्टेप फेल हुआ। उसके नीचे दिया उपाय पढ़ें।');
  static final LText _again = t('Run the check again', 'जांच फिर चलाएं');
  static final LText _noUser = t('Sign in first (More tab), then run this check.', 'पहले साइन इन करें (More टैब), फिर यह जांच चलाएं।');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      // after the first frame (setState is not wanted during the build itself)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  static LText _hintFor(String code) {
    switch (code) {
      case 'permission-denied':
        return t(
          'Firebase is refusing access. Open the Firebase console > Firestore Database > Rules, replace everything with the rules from firebase/firestore.rules in your repository, and press Publish. Then run this check again.',
          'Firebase पहुंच से मना कर रहा है। Firebase console > Firestore Database > Rules खोलें, सब कुछ हटाकर अपने रिपॉज़िटरी की firebase/firestore.rules के नियम चिपकाएं और Publish दबाएं। फिर यह जांच दोबारा चलाएं।',
        );
      case 'not-found':
      case 'failed-precondition':
        return t(
          'The database may not exist yet. Firebase console > Build > Firestore Database > Create database (production mode, region asia-south1), then publish the rules and run this check again.',
          'डेटाबेस शायद अभी बना नहीं है। Firebase console > Build > Firestore Database > Create database (production mode, region asia-south1) करें, फिर रूल्स Publish करें और जांच दोबारा चलाएं।',
        );
      case 'unauthenticated':
        return t(
          'Your sign-in has expired. Sign out and sign in with Google again.',
          'आपका साइन-इन खत्म हो गया है। साइन आउट करके Google से फिर साइन इन करें।',
        );
      case 'unavailable':
      case 'timeout':
      case 'deadline-exceeded':
        return t(
          'No answer from the server. Check the internet connection. If the internet is fine, enable the "Cloud Firestore API" for your project in Google Cloud console (APIs & Services) and try again.',
          'सर्वर से जवाब नहीं मिला। इंटरनेट कनेक्शन जांचें। इंटरनेट ठीक है तो Google Cloud console (APIs & Services) में अपने प्रोजेक्ट के लिए "Cloud Firestore API" चालू करें और फिर कोशिश करें।',
        );
      default:
        return t(
          'Send this error code to the developer so it can be fixed.',
          'यह एरर कोड डेवलपर को भेजें ताकि इसे ठीक किया जा सके।',
        );
    }
  }

  /// Runs one step: shows it as "running", then as OK or failed (with the reason).
  Future<bool> _step(LText title, Future<String?> Function() action) async {
    final index = _steps.length;
    setState(() => _steps.add(_Step(title, _Status.running)));
    try {
      final note = await action();
      if (!mounted) return false;
      setState(() => _steps[index] = _Step(title, _Status.ok, detail: note ?? ''));
      return true;
    } on FirebaseException catch (e) {
      if (!mounted) return false;
      final code = e.code;
      setState(() => _steps[index] = _Step(
            title,
            _Status.failed,
            detail: '[${e.plugin}/$code] ${e.message ?? ''}'.trim(),
            hint: _hintFor(code),
          ));
      return false;
    } on TimeoutException {
      if (!mounted) return false;
      setState(() => _steps[index] = _Step(title, _Status.failed, detail: 'timeout', hint: _hintFor('timeout')));
      return false;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _steps[index] = _Step(title, _Status.failed, detail: '$e', hint: _hintFor('other')));
      return false;
    }
  }

  DocumentReference<Map<String, dynamic>>? _folderFor(String uid) {
    try {
      return FirebaseFirestore.instance.collection('users').doc(uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> _run() async {
    final auth = AppScope.of(context).auth;
    setState(() {
      _steps.clear();
      _running = true;
    });
    const wait = Duration(seconds: 12);
    final user = auth.user;
    if (user == null) {
      setState(() {
        _steps.add(_Step(_signedIn, _Status.failed, hint: _noUser));
        _running = false;
      });
      return;
    }
    setState(() => _steps.add(_Step(_signedIn, _Status.ok, detail: user.email)));

    final folder = _folderFor(user.uid);
    if (folder == null) {
      setState(() {
        _steps.add(_Step(_readProfile, _Status.failed, detail: 'Firebase is not set up in this build', hint: _hintFor('other')));
        _running = false;
      });
      return;
    }

    var ok = await _step(_readProfile, () async {
      await folder.get(const GetOptions(source: Source.server)).timeout(wait);
      return null;
    });
    if (ok) {
      ok = await _step(_readList, () async {
        final snap = await folder.collection('expenses').limit(1).get(const GetOptions(source: Source.server)).timeout(wait);
        return snap.docs.isEmpty ? 'empty' : 'ok';
      });
    }
    if (ok) {
      ok = await _step(_writeTest, () async {
        await folder.collection('diagnostics').doc('ping').set({'at': FieldValue.serverTimestamp()}).timeout(wait);
        return null;
      });
    }
    if (ok) {
      await _step(_deleteTest, () async {
        await folder.collection('diagnostics').doc('ping').delete().timeout(wait);
        return null;
      });
    }
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = _steps.any((s) => s.status == _Status.failed);
    final done = !_running && _steps.isNotEmpty && !failed;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, _title), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final s in _steps)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: s.status == _Status.failed ? scheme.errorContainer : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: s.status == _Status.failed ? scheme.error : scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        switch (s.status) {
                          _Status.running => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                          _Status.ok => const Icon(Icons.check_circle_rounded, color: Colors.green),
                          _Status.failed => Icon(Icons.cancel_rounded, color: scheme.error),
                        },
                        const SizedBox(width: 12),
                        Expanded(child: Text(tr(context, s.title), style: const TextStyle(fontWeight: FontWeight.w700))),
                      ],
                    ),
                    if (s.detail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SelectableText(s.detail, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ),
                    if (s.hint != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(tr(context, s.hint!)),
                      ),
                  ],
                ),
              ),
            if (done)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(context, _allGood), style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700)),
              ),
            if (failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(tr(context, _problem), style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr(context, _again)),
            ),
          ],
        ),
      ),
    );
  }
}
