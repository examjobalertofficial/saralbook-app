import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_backend.dart';

/// Push notifications ("new post", "updated post") with one on/off switch.
///
/// * The OneSignal App ID is public and comes from the website settings, so it
///   can be added or changed without a new APK. Until it is there, [available]
///   is false and the switch is hidden.
/// * Nothing here ever throws: a phone without push support simply gets none.
class PushController extends ChangeNotifier {
  PushController(this._prefs, {PushBackend? backend}) : _backend = backend ?? const OneSignalPushBackend();

  static const String enabledKey = 'push.enabled';
  static const String askedKey = 'push.asked';

  /// Safety net. Set (to the time) just before the push service starts and
  /// removed when it has started. If it is still there at the next launch, the
  /// last start never finished (the phone choked on it), so push is paused for
  /// [pauseFor] and the app opens normally instead of getting stuck.
  static const String guardKey = 'push.guard';
  static const String pausedUntilKey = 'push.pausedUntil';
  static const Duration pauseFor = Duration(days: 3);

  /// OneSignal App IDs look like 8-4-4-4-12 hex digits.
  static final RegExp appIdPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  final SharedPreferences _prefs;
  final PushBackend _backend;

  String _appId = '';
  bool _started = false;
  bool _starting = false;

  /// Notifications are set up (an App ID is known and the service started).
  bool get available => _started;

  /// The person's choice. On by default.
  bool get enabled => _prefs.getBool(enabledKey) ?? true;

  /// Called whenever the website settings are (re)loaded. Starts the service once.
  Future<void> configure(String appId) async {
    final id = appId.trim();
    if (id == _appId || _starting || !appIdPattern.hasMatch(id)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((_prefs.getInt(pausedUntilKey) ?? 0) > now) return;
    if (_prefs.containsKey(guardKey)) {
      await _prefs.remove(guardKey);
      await _prefs.setInt(pausedUntilKey, now + pauseFor.inMilliseconds);
      return;
    }
    _starting = true;
    try {
      await _prefs.setInt(guardKey, now);
      await _backend.start(id);
      await _prefs.remove(guardKey);
      _appId = id;
      _started = true;
      notifyListeners();
      await _applyChoice();
    } catch (_) {
      // no push service on this phone: stay unavailable
      await _prefs.remove(guardKey);
    } finally {
      _starting = false;
    }
  }

  /// First run: ask once (Android shows its own permission box). Later runs just
  /// keep the choice the person made.
  Future<void> _applyChoice() async {
    try {
      if (enabled) {
        final asked = _prefs.getBool(askedKey) ?? false;
        if (!asked) {
          await _prefs.setBool(askedKey, true);
        }
        await _backend.optIn();
      } else {
        await _backend.optOut();
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(enabledKey, value);
    await _prefs.setBool(askedKey, true);
    notifyListeners();
    if (!_started) return;
    try {
      if (value) {
        await _backend.optIn();
      } else {
        await _backend.optOut();
      }
    } catch (_) {}
  }
}
