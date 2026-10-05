import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_backend.dart';
import 'firebase_backend.dart';

enum AuthStatus { checking, unavailable, signedOut, signingIn, signedIn }

enum AuthMessage { none, cancelled, failed }

/// Who is signed in, and the actions to sign in / switch / sign out.
/// The app never requires this for normal use; personal features ask for it.
class AuthController extends ChangeNotifier {
  AuthController(Future<AuthBackend> Function() backendFactory)
      : _factory = backendFactory;

  /// Real Google + Firebase sign-in.
  AuthController.firebase() : this(FirebaseAuthBackend.create);

  /// Already-created backend (used by tests).
  AuthController.ready(AuthBackend backend) : this(() async => backend);

  final Future<AuthBackend> Function() _factory;
  AuthBackend? _backend;
  StreamSubscription<AppUser?>? _sub;
  bool _started = false;

  AuthStatus _status = AuthStatus.checking;
  AppUser? _user;
  AuthMessage _message = AuthMessage.none;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null && _status != AuthStatus.checking;
  bool get isAvailable =>
      _status != AuthStatus.unavailable && _status != AuthStatus.checking;

  /// Last problem to show once (then call [clearMessage]).
  AuthMessage get message => _message;

  void clearMessage() {
    if (_message == AuthMessage.none) return;
    _message = AuthMessage.none;
    notifyListeners();
  }

  /// Safe to call more than once. Never throws.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      _backend = await _factory();
    } catch (_) {
      _backend = null;
    }
    final backend = _backend;
    if (backend == null || !backend.isConfigured) {
      _status = AuthStatus.unavailable;
      notifyListeners();
      return;
    }
    _user = backend.currentUser;
    _status = _user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    _sub = backend.userChanges.listen(_onUser, onError: (_) {});
    notifyListeners();
  }

  void _onUser(AppUser? u) {
    _user = u;
    if (_status != AuthStatus.signingIn) {
      _status = u == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    }
    notifyListeners();
  }

  bool get canSignIn =>
      _backend != null &&
      (_status == AuthStatus.signedOut || _status == AuthStatus.signedIn);

  /// Shows the Google account chooser. Also used to switch account:
  /// if the person cancels, they stay signed in as before.
  Future<bool> signIn() async {
    final backend = _backend;
    if (backend == null || !canSignIn) return false;
    final previous = _status;
    _status = AuthStatus.signingIn;
    _message = AuthMessage.none;
    notifyListeners();
    try {
      final u = await backend.signInWithGoogle();
      _user = u;
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    } on AuthCancelledException {
      _status = previous;
      _message = AuthMessage.cancelled;
      notifyListeners();
      return false;
    } catch (_) {
      _status = previous;
      _message = AuthMessage.failed;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.signOut();
    } catch (_) {/* treat as signed out locally anyway */}
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
