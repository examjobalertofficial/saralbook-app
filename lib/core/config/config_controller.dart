import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/endpoints.dart';
import '../../config/websites.dart';
import '../cache/cache_store.dart';
import 'control.dart';
import 'control_backend.dart';
import 'remote_config.dart';

/// Holds the current app configuration. Starts with the saved copy (or the
/// built-in defaults) so the app never waits for the network, then refreshes
/// quietly in the background.
class ConfigController extends ChangeNotifier {
  ConfigController(this._cache, {http.Client? client, ControlBackend? control})
      : _client = client ?? http.Client(),
        _control = control ?? const NoControlBackend();

  static const String _cacheKey = 'remote_config';
  static const String _controlKey = 'control_override';
  static const Duration maxCachedAge = Duration(days: 7);

  final CacheStore _cache;
  final http.Client _client;
  final ControlBackend _control;

  /// What the website (or the built-in defaults) says.
  AppRemoteConfig _base = AppRemoteConfig.defaults();

  /// The owner's switches from the cloud, on top of [_base].
  AppControl _override = AppControl.empty;

  /// What the app actually uses: [_base] + [_override].
  AppRemoteConfig _config = AppRemoteConfig.defaults();
  bool _refreshing = false;
  bool _controlRefreshing = false;
  int _refreshToken = 0;

  /// This app's build number (the number after + in the version). 0 = unknown,
  /// and then no update rule ever blocks anything.
  int _currentBuild = 0;

  int get currentBuild => _currentBuild;

  void setCurrentBuild(int build) {
    if (build == _currentBuild) return;
    _currentBuild = build;
    notifyListeners();
  }

  /// The app must be updated before it can be used.
  bool get updateRequired => _config.update.mustUpdate(_currentBuild);

  /// A newer version exists (a gentle note only).
  bool get updateAvailable => !updateRequired && _config.update.canUpdate(_currentBuild);

  UpdatePolicy get update => _config.update;

  /// The saved owner switches (shown in the Admin panel).
  AppControl get control => _override;

  bool flagOn(String id) => _config.flagOn(id);

  bool toolOn(String id) => _config.toolOn(id);

  void _recompute() => _config = _base.withControl(_override);

  AppRemoteConfig get config => _config;
  List<Website> get sites => _config.sites;
  Maintenance get maintenance => _config.maintenance;
  List<Announcement> get announcements => _config.announcements;
  List<HomeSection> get sections => _config.sections;

  /// Increases on every manual refresh so Home feeds know to reload.
  int get refreshToken => _refreshToken;

  List<Website> sitesByIds(List<String> ids) => _config.sitesByIds(ids);

  void loadCached() {
    final raw = _cache.get(_cacheKey, maxAge: maxCachedAge);
    if (raw != null) {
      final parsed = AppRemoteConfig.tryParse(raw);
      if (parsed != null) _base = parsed;
    }
    final rawControl = _cache.get(_controlKey, maxAge: maxCachedAge);
    if (rawControl != null) {
      try {
        _override = AppControl.fromMap(jsonDecode(rawControl));
      } catch (_) {/* ignore a damaged copy */}
    }
    _recompute();
  }

  void useDefaults() {
    _base = AppRemoteConfig.defaults();
    _override = AppControl.empty;
    _recompute();
    notifyListeners();
  }

  /// Fetches the owner's switches from the cloud. Never throws; when the cloud
  /// cannot be reached the last saved switches stay in place.
  Future<void> refreshControl() async {
    if (_controlRefreshing) return;
    _controlRefreshing = true;
    try {
      final data = await _control.fetchControl();
      final next = AppControl.fromMap(data);
      if (jsonEncode(next.toMap()) != jsonEncode(_override.toMap())) {
        await applyControl(next);
      }
    } catch (_) {
      // offline / not configured: keep what we have
    } finally {
      _controlRefreshing = false;
    }
  }

  /// Uses (and remembers) these switches.
  Future<void> applyControl(AppControl c) async {
    _override = c;
    _recompute();
    notifyListeners();
    try {
      await _cache.put(_controlKey, jsonEncode(c.toMap()));
    } catch (_) {}
  }

  /// Fetches the latest configuration. Never throws: on any problem the
  /// current configuration stays in place.
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (force) {
      _refreshToken++;
      notifyListeners();
    }
    try {
      final response = await _client
          .get(Uri.parse(Endpoints.configUrl))
          .timeout(Endpoints.requestTimeout);
      if (response.statusCode == 200) {
        final raw = utf8.decode(response.bodyBytes, allowMalformed: true);
        final parsed = AppRemoteConfig.tryParse(raw);
        if (parsed != null) {
          _base = parsed;
          _recompute();
          await _cache.put(_cacheKey, raw);
          notifyListeners();
        }
      } else if (response.statusCode == 404 || response.statusCode == 410) {
        // Config was removed on purpose: go back to built-in defaults.
        await _cache.remove(_cacheKey);
        _base = AppRemoteConfig.defaults();
        _recompute();
        notifyListeners();
      }
    } catch (_) {
      // Offline / slow / server error: keep what we have.
    } finally {
      _refreshing = false;
    }
    unawaited(refreshControl());
  }
}
