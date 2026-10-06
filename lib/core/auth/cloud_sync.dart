import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../home/home_layout.dart';
import '../settings/settings_controller.dart';
import 'auth_controller.dart';
import 'prefs_snapshot.dart';

/// Keeps the signed-in person's profile and preferences in
/// `users/{uid}` (Firestore). Works offline (Firestore queues the writes).
/// Every failure is silent: the app never depends on this.
class CloudProfileSync {
  CloudProfileSync({
    required this.auth,
    required this.settings,
    required this.layout,
  });

  final AuthController auth;
  final SettingsController settings;
  final HomeLayoutController layout;

  String? _uid;
  bool _applying = false;
  bool _suspended = false;
  Timer? _debounce;

  void start() {
    auth.addListener(_onAuth);
    settings.addListener(_schedulePush);
    layout.addListener(_schedulePush);
    _onAuth();
  }

  PrefsSnapshot _current() => PrefsSnapshot(
        themeMode: settings.themeMode,
        language: settings.languageCode,
        hiddenSections: layout.hiddenIds,
        sectionOrder: layout.orderIds,
      );

  void _onAuth() {
    final user = auth.user;
    final uid = user?.uid;
    if (uid == _uid) return;
    _uid = uid;
    _suspended = false;
    _debounce?.cancel();
    if (user != null) {
      unawaited(_pull(user.uid, user.name, user.email, user.photoUrl));
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> _pull(String uid, String name, String email, String? photo) async {
    try {
      final ref = _doc(uid);
      final snap = await ref.get();
      if (_uid != uid) return; // account changed meanwhile
      final remote = PrefsSnapshot.fromMap(snap.data()?['prefs']);
      if (remote != null) {
        _applying = true;
        try {
          await settings.setThemeMode(remote.themeMode);
          await settings.setLanguage(remote.language);
          await layout.applyRemote(
            hidden: remote.hiddenSections,
            order: remote.sectionOrder,
          );
        } finally {
          _applying = false;
        }
      }
      await ref.set({
        'profile': {'name': name, 'email': email, 'photoUrl': photo},
        'lastLoginAt': FieldValue.serverTimestamp(),
        if (remote == null) 'prefs': _current().toMap(),
      }, SetOptions(merge: true));
    } catch (_) {/* offline or rules not set yet: ignore */}
  }

  void _schedulePush() {
    if (_uid == null || _applying || _suspended) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _push);
  }

  Future<void> _push() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _doc(uid).set({
        'prefs': _current().toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* try again on next change */}
  }

  /// Part of "Delete my data": removes the profile document and stops
  /// saving preferences until the next sign-in. Needs the internet.
  Future<void> deleteProfile() async {
    final uid = _uid;
    if (uid == null) return;
    _debounce?.cancel();
    _suspended = true;
    await _doc(uid).delete();
  }

  void dispose() {
    _debounce?.cancel();
    auth.removeListener(_onAuth);
    settings.removeListener(_schedulePush);
    layout.removeListener(_schedulePush);
  }
}
