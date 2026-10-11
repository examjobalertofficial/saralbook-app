import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_controller.dart';

/// Where the owner's switches (`appConfig/main`) and the list of admins
/// (`admins/{uid}`) live. Firestore does it for real; tests use a memory copy.
abstract class ControlBackend {
  /// The saved switches (empty map = none saved). Throws when unreachable.
  Future<Map<String, dynamic>> fetchControl();

  /// true only if `admins/{uid}` exists. Create that document by hand in the
  /// Firebase console - the app can never create it (the rules forbid it).
  Future<bool> isAdmin(String uid);

  /// Replaces the saved switches. The security rules allow it only for admins.
  Future<void> saveControl(Map<String, dynamic> data);
}

/// Used when there is no cloud: no admins, nothing saved.
class NoControlBackend implements ControlBackend {
  const NoControlBackend();

  @override
  Future<Map<String, dynamic>> fetchControl() async => const <String, dynamic>{};

  @override
  Future<bool> isAdmin(String uid) async => false;

  @override
  Future<void> saveControl(Map<String, dynamic> data) async =>
      throw StateError('Cloud is not available');
}

class FirestoreControlBackend implements ControlBackend {
  FirestoreControlBackend(this._auth);

  final AuthController _auth;

  static const Duration _timeout = Duration(seconds: 10);

  /// Firebase starts a moment after the app; wait for it (at most ~8 s).
  Future<FirebaseFirestore> _db() async {
    for (var i = 0; i < 40; i++) {
      if (_auth.status != AuthStatus.checking) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!_auth.isAvailable) throw StateError('Cloud is not available');
    return FirebaseFirestore.instance;
  }

  @override
  Future<Map<String, dynamic>> fetchControl() async {
    final db = await _db();
    final snap = await db.collection('appConfig').doc('main').get().timeout(_timeout);
    return snap.data() ?? <String, dynamic>{};
  }

  @override
  Future<bool> isAdmin(String uid) async {
    final db = await _db();
    final snap = await db.collection('admins').doc(uid).get().timeout(_timeout);
    return snap.exists;
  }

  @override
  Future<void> saveControl(Map<String, dynamic> data) async {
    final db = await _db();
    await db.collection('appConfig').doc('main').set(data).timeout(_timeout);
  }
}

/// For tests.
class MemoryControlBackend implements ControlBackend {
  MemoryControlBackend({Set<String>? admins, Map<String, dynamic>? stored})
      : admins = admins ?? <String>{},
        stored = stored ?? <String, dynamic>{};

  final Set<String> admins;
  Map<String, dynamic> stored;
  bool failing = false;
  int fetchCalls = 0;
  int saveCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchControl() async {
    fetchCalls++;
    if (failing) throw StateError('offline');
    return Map<String, dynamic>.of(stored);
  }

  @override
  Future<bool> isAdmin(String uid) async {
    if (failing) throw StateError('offline');
    return admins.contains(uid);
  }

  @override
  Future<void> saveControl(Map<String, dynamic> data) async {
    saveCalls++;
    if (failing) throw StateError('offline');
    stored = Map<String, dynamic>.of(data);
  }
}
