import 'dart:convert';

import '../../config/endpoints.dart';
import '../../config/websites.dart';
import '../security/safe_url.dart';

class Maintenance {
  final bool enabled;

  /// true = full-screen "under maintenance"; false = just a banner on Home.
  final bool blocking;
  final String message;
  const Maintenance({
    required this.enabled,
    required this.blocking,
    required this.message,
  });
  static const none = Maintenance(enabled: false, blocking: false, message: '');
}

class Announcement {
  final String id;
  final String title;
  final String message;
  final String? url;
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.url,
  });
}

/// One block on the Home screen. [type] decides how it is drawn:
/// `platforms`, `feed`, `recent`. Unknown types are ignored, so the website
/// can add new types later without breaking old apps.
class HomeSection {
  final String id;
  final String type;
  final String title;
  final String titleHi;
  final String feedUrl;

  const HomeSection({
    required this.id,
    required this.type,
    this.title = '',
    this.titleHi = '',
    this.feedUrl = '',
  });

  String titleFor(String languageCode) =>
      languageCode == 'hi' && titleHi.isNotEmpty ? titleHi : title;
}

class AppRemoteConfig {
  final Maintenance maintenance;
  final List<Announcement> announcements;
  final List<Website> sites;
  final List<HomeSection> sections;

  const AppRemoteConfig({
    required this.maintenance,
    required this.announcements,
    required this.sites,
    required this.sections,
  });

  static const Set<String> supportedSectionTypes = {'platforms', 'feed', 'recent'};

  static const List<HomeSection> defaultSections = [
    HomeSection(id: 'platforms', type: 'platforms'),
    HomeSection(
      id: 'latest_jobs',
      type: 'feed',
      title: 'Latest Jobs & Updates',
      titleHi: 'ताज़ा नौकरियां और अपडेट',
      feedUrl: Endpoints.examJobAlertPosts,
    ),
    HomeSection(
      id: 'saralbook_updates',
      type: 'feed',
      title: 'From SaralBook',
      titleHi: 'सरलबुक से',
      feedUrl: Endpoints.saralBookPosts,
    ),
    HomeSection(id: 'recent', type: 'recent'),
  ];

  /// Built into the app. Used when there is no internet and no saved copy.
  factory AppRemoteConfig.defaults() => const AppRemoteConfig(
        maintenance: Maintenance.none,
        announcements: [],
        sites: Websites.all,
        sections: defaultSections,
      );

  Website? siteById(String id) {
    for (final s in sites) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Website> sitesByIds(List<String> ids) => [
        for (final id in ids) ...sites.where((s) => s.id == id),
      ];

  /// Returns null if [raw] is not usable JSON. Never throws.
  static AppRemoteConfig? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      return _fromMap(json);
    } catch (_) {
      return null;
    }
  }

  static String _str(Object? v, int max) {
    if (v is! String) return '';
    final t = v.trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  static bool _bool(Object? v, {required bool orElse}) => v is bool ? v : orElse;

  static final RegExp _idPattern = RegExp(r'^[a-z0-9_-]{1,40}$');

  static AppRemoteConfig _fromMap(Map<String, dynamic> json) {
    // Maintenance
    var maintenance = Maintenance.none;
    final m = json['maintenance'];
    if (m is Map<String, dynamic>) {
      maintenance = Maintenance(
        enabled: _bool(m['enabled'], orElse: false),
        blocking: _bool(m['blocking'], orElse: false),
        message: _str(m['message'], 400),
      );
    }

    // Announcements (max 3)
    final announcements = <Announcement>[];
    final a = json['announcements'];
    if (a is List) {
      for (final item in a) {
        if (item is! Map<String, dynamic>) continue;
        final title = _str(item['title'], 120);
        final message = _str(item['message'], 400);
        if (title.isEmpty && message.isEmpty) continue;
        final url = _str(item['url'], 2000);
        final id = _str(item['id'], 40);
        announcements.add(Announcement(
          id: id.isEmpty ? 'a${announcements.length}' : id,
          title: title,
          message: message,
          url: SafeUrl.isAllowed(url) ? url : null,
        ));
        if (announcements.length == 3) break;
      }
    }

    // Services: can only adjust the websites the app already knows.
    final overrides = json['services'];
    final sites = <Website>[];
    for (final site in Websites.all) {
      var s = site;
      final o = overrides is Map<String, dynamic> ? overrides[site.id] : null;
      if (o is Map<String, dynamic>) {
        final name = _str(o['name'], 60);
        final desc = _str(o['description'], 200);
        final url = _str(o['url'], 2000);
        final msg = _str(o['message'], 300);
        s = s.copyWith(
          name: name.isEmpty ? null : name,
          description: desc.isEmpty ? null : desc,
          url: SafeUrl.isAllowed(url) ? url : null,
          enabled: _bool(o['enabled'], orElse: true),
          unavailableMessage: msg.isEmpty ? null : msg,
        );
      }
      sites.add(s);
    }

    // Home sections (max 12). Missing/empty -> built-in defaults.
    var sections = defaultSections;
    final rawSections = json['sections'];
    if (rawSections is List && rawSections.isNotEmpty) {
      final parsed = <HomeSection>[];
      final seen = <String>{};
      for (final item in rawSections) {
        if (item is! Map<String, dynamic>) continue;
        final id = _str(item['id'], 40);
        final type = _str(item['type'], 20);
        if (!_idPattern.hasMatch(id) || seen.contains(id)) continue;
        if (!supportedSectionTypes.contains(type)) continue;
        final feedUrl = _str(item['feedUrl'], 2000);
        if (type == 'feed' && !SafeUrl.isAllowed(feedUrl)) continue;
        if (!_bool(item['enabled'], orElse: true)) continue;
        seen.add(id);
        parsed.add(HomeSection(
          id: id,
          type: type,
          title: _str(item['title'], 80),
          titleHi: _str(item['titleHi'], 80),
          feedUrl: type == 'feed' ? feedUrl : '',
        ));
        if (parsed.length == 12) break;
      }
      if (parsed.isNotEmpty) sections = parsed;
    }

    return AppRemoteConfig(
      maintenance: maintenance,
      announcements: announcements,
      sites: sites,
      sections: sections,
    );
  }
}
