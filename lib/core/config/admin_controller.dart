import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';
import 'config_controller.dart';
import 'control.dart';
import 'control_backend.dart';

/// Knows whether the signed-in person is an owner/admin and saves the owner's
/// switches. The check is done by the cloud (`admins/{uid}` document), never by
/// anything stored in the app, and the cloud rules enforce it again on every save.
class AdminController extends ChangeNotifier {
  AdminController({
    required AuthController auth,
    required ControlBackend backend,
    required ConfigController config,
    DateTime Function()? now,
  })  : _auth = auth,
        _backend = backend,
        _config = config,
        _now = now ?? DateTime.now {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  final AuthController _auth;
  final ControlBackend _backend;
  final ConfigController _config;
  final DateTime Function() _now;

  bool _isAdmin = false;
  String? _checkedUid;
  bool _disposed = false;

  bool get isAdmin => _isAdmin;

  Future<void> _onAuth() async {
    final uid = _auth.user?.uid;
    if (uid == null) {
      _checkedUid = null;
      _set(false);
      return;
    }
    if (uid == _checkedUid) return;
    _checkedUid = uid;
    bool result;
    try {
      result = await _backend.isAdmin(uid);
    } catch (_) {
      result = false;
      _checkedUid = null; // try again on the next change
    }
    // the person may have signed out / switched while we were asking
    if (_auth.user?.uid != uid) return;
    _set(result);
  }

  /// Forces a fresh check (e.g. after the owner added the admin document).
  Future<void> recheck() {
    _checkedUid = null;
    return _onAuth();
  }

  void _set(bool v) {
    if (_disposed || v == _isAdmin) return;
    _isAdmin = v;
    notifyListeners();
  }

  /// Saves the switches for everyone. false = not admin or the cloud refused.
  Future<bool> save(AppControl c) async {
    final uid = _auth.user?.uid;
    if (!_isAdmin || uid == null) return false;
    final data = c.toMap()
      ..['updatedBy'] = uid
      ..['updatedAt'] = _now().millisecondsSinceEpoch;
    try {
      await _backend.saveControl(data);
    } catch (_) {
      return false;
    }
    await _config.applyControl(AppControl.fromMap(data));
    return true;
  }

  /// Removes every switch (everything back to what the website says).
  Future<bool> reset() => save(AppControl.empty);

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}
