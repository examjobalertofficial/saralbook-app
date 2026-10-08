import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_controller.dart';
import 'auth/cloud_sync.dart';
import 'cache/cache_store.dart';
import 'config/config_controller.dart';
import 'expense/currency.dart';
import 'feed/feed_repository.dart';
import 'home/home_layout.dart';
import 'home/recents_controller.dart';
import 'personal/cloud_collection.dart';
import 'personal/personal_data.dart';
import 'settings/settings_controller.dart';

/// Everything the screens share, created once at app start.
class AppServices {
  AppServices({
    required this.settings,
    required this.cache,
    required this.config,
    required this.feeds,
    required this.layout,
    required this.recents,
    required this.auth,
    required this.personal,
    required this.sync,
    required this.rates,
  });

  final SettingsController settings;
  final CacheStore cache;
  final ConfigController config;
  final FeedRepository feeds;
  final HomeLayoutController layout;
  final RecentsController recents;
  final AuthController auth;
  final PersonalDataHub personal;
  final CloudProfileSync sync;
  final RateService rates;

  static Future<AppServices> create() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await SettingsController.load();
    final cache = CacheStore(prefs);
    final config = ConfigController(cache)..loadCached();
    final layout = HomeLayoutController.load(prefs);
    final rates = RateService(cache: cache, prefs: prefs)..loadCached();
    final auth = AuthController.firebase();
    // Keeps theme/language/Home layout in the cloud for signed-in people.
    final sync = CloudProfileSync(auth: auth, settings: settings, layout: layout)..start();
    return AppServices(
      settings: settings,
      cache: cache,
      config: config,
      feeds: FeedRepository(cache),
      layout: layout,
      recents: RecentsController.load(prefs),
      auth: auth,
      sync: sync,
      rates: rates,
      personal: PersonalDataHub(
        auth,
        (uid, name) => FirestoreCollection(
          uid,
          name,
          orderBy: name == 'study_sessions' ? 'startedAt' : (name == 'expenses' ? 'date' : null),
          limit: name == 'study_sessions' ? 2000 : (name == 'expenses' ? 5000 : null),
        ),
      ),
    );
  }

  /// "Clear cache" in More: removes saved downloads, keeps user data.
  Future<void> clearCache() async {
    await cache.clear();
    config.useDefaults();
    unawaited(config.refresh(force: true));
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
