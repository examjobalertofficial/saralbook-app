import 'dart:async';

import 'package:app/core/auth/auth_backend.dart';

/// A pretend sign-in system for tests (no Firebase, no network).
class FakeAuthBackend implements AuthBackend {
  FakeAuthBackend({this.configured = true, AppUser? start}) : _current = start;

  final bool configured;
  AppUser? _current;
  final _changes = StreamController<AppUser?>.broadcast();

  /// What the next sign-in does: a user, or an exception.
  Object nextResult = const AppUser(uid: 'a', name: 'Asha Verma', email: 'asha@gmail.com');
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isConfigured => configured;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> get userChanges => _changes.stream;

  @override
  Future<AppUser> signInWithGoogle() async {
    signInCalls++;
    final r = nextResult;
    if (r is AppUser) {
      _current = r;
      _changes.add(r);
      return r;
    }
    throw r;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _changes.add(null);
  }
}
