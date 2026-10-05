import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/endpoints.dart';
import '../../config/websites.dart';
import '../cache/cache_store.dart';
import 'remote_config.dart';

/// Holds the current app configuration. Starts with the saved copy (or the
/// built-in defaults) so the app never waits for the network, then refreshes
/// quietly in the background.
class ConfigController extends ChangeNotifier {
  ConfigController(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  static const String _cacheKey = 'remote_config';
  static const Duration maxCachedAge = Duration(days: 7);

  final CacheStore _cache;
  final http.Client _client;

  AppRemoteConfig _config = AppRemoteConfig.defaults();
  bool _refreshing = false;
  int _refreshToken = 0;

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
    if (raw == null) return;
    final parsed = AppRemoteConfig.tryParse(raw);
    if (parsed != null) _config = parsed;
  }

  void useDefaults() {
    _config = AppRemoteConfig.defaults();
    notifyListeners();
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
          _config = parsed;
          await _cache.put(_cacheKey, raw);
          notifyListeners();
        }
      } else if (response.statusCode == 404 || response.statusCode == 410) {
        // Config was removed on purpose: go back to built-in defaults.
        await _cache.remove(_cacheKey);
        _config = AppRemoteConfig.defaults();
        notifyListeners();
      }
    } catch (_) {
      // Offline / slow / server error: keep what we have.
    } finally {
      _refreshing = false;
    }
  }
}
