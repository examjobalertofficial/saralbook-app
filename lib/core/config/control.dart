import '../../config/app_info.dart';
import '../security/safe_url.dart';

/// Switches the owner can turn off from the website or the Admin panel
/// without a new APK. Only these names are understood by the app.
class FeatureFlags {
  static const String groups = 'groups';
  static const String groupChat = 'group_chat';
  static const String expenseTracker = 'expense_tracker';

  static const List<String> all = [groups, groupChat, expenseTracker];

  static const Map<String, String> labels = {
    groups: 'Group Expenses',
    groupChat: 'Group chat',
    expenseTracker: 'Expense Tracker',
  };
}

final RegExp _toolIdPattern = RegExp(r'^[a-z0-9_]{1,40}$');

int _int(Object? v) {
  final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  return n < 0 ? 0 : (n > 100000000 ? 100000000 : n);
}

String _text(Object? v, int max) {
  if (v is! String) return '';
  final t = v.trim();
  return t.length > max ? t.substring(0, max) : t;
}

/// `{"groups": false}` -> only known names with true/false values are kept.
Map<String, bool> parseFlags(Object? raw) {
  final out = <String, bool>{};
  if (raw is Map) {
    for (final id in FeatureFlags.all) {
      final v = raw[id];
      if (v is bool) out[id] = v;
      if (v is num) out[id] = v != 0;
    }
  }
  return out;
}

/// A list (or comma separated text) of tool ids. Bad ids are dropped.
Set<String> parseToolIds(Object? raw) {
  final items = <String>[];
  if (raw is List) {
    for (final v in raw) {
      if (v is String) items.add(v);
    }
  } else if (raw is String) {
    items.addAll(raw.split(RegExp(r'[,\s]+')));
  }
  final out = <String>{};
  for (final i in items) {
    final id = i.trim().toLowerCase();
    if (_toolIdPattern.hasMatch(id)) out.add(id);
    if (out.length >= 80) break;
  }
  return out;
}

/// "Please update" rules, compared with the app's build number
/// (the number after the + in the version, e.g. 1.11.0+13 -> 13).
class UpdatePolicy {
  /// Older builds than this must update (the app shows an update screen).
  final int minBuild;

  /// Builds older than this see a gentle "update available" note on Home.
  final int latestBuild;
  final String message;
  final String url;

  const UpdatePolicy({
    this.minBuild = 0,
    this.latestBuild = 0,
    this.message = '',
    this.url = '',
  });

  static const UpdatePolicy none = UpdatePolicy();

  bool get isSet => minBuild > 0 || latestBuild > 0;

  /// [build] 0 means "unknown": then nothing is ever blocked.
  bool mustUpdate(int build) => build > 0 && minBuild > build;

  bool canUpdate(int build) => build > 0 && latestBuild > build;

  static bool isSafeTarget(String url) =>
      SafeUrl.isAllowed(url) || url.startsWith('https://play.google.com/store/apps/details?id=com.saralbook.app');

  /// Where the "Update" button goes: the given address if it is safe, else Google Play.
  String get target => isSafeTarget(url) ? url : AppInfo.playStoreUrl;

  static UpdatePolicy fromMap(Object? raw) {
    if (raw is! Map) return none;
    return UpdatePolicy(
      minBuild: _int(raw['minBuild']),
      latestBuild: _int(raw['latestBuild']),
      message: _text(raw['message'], 300),
      url: _text(raw['url'], 2000),
    );
  }

  Map<String, dynamic> toMap() => {
        'minBuild': minBuild,
        'latestBuild': latestBuild,
        'message': message,
        'url': url,
      };
}

/// The owner's switches kept in Firestore (`appConfig/main`), editable from the
/// Admin panel. They sit on top of the WordPress settings and can only make the
/// app *more* restricted (maintenance on, feature off, tool off) or set the
/// update rules - never open anything that WordPress closed.
class AppControl {
  final bool maintenanceEnabled;
  final bool maintenanceBlocking;
  final String maintenanceMessage;
  final Map<String, bool> flags;
  final Set<String> disabledTools;
  final UpdatePolicy update;
  final int updatedAt;
  final String updatedBy;

  const AppControl({
    this.maintenanceEnabled = false,
    this.maintenanceBlocking = false,
    this.maintenanceMessage = '',
    this.flags = const {},
    this.disabledTools = const {},
    this.update = UpdatePolicy.none,
    this.updatedAt = 0,
    this.updatedBy = '',
  });

  static const AppControl empty = AppControl();

  bool flagOn(String id) => flags[id] ?? true;

  /// Never throws; anything unusable gives [empty].
  factory AppControl.fromMap(Object? raw) {
    if (raw is! Map) return empty;
    final m = raw['maintenance'];
    final mm = m is Map ? m : const <Object?, Object?>{};
    return AppControl(
      maintenanceEnabled: mm['enabled'] == true,
      maintenanceBlocking: mm['blocking'] == true,
      maintenanceMessage: _text(mm['message'], 400),
      flags: parseFlags(raw['flags']),
      disabledTools: parseToolIds(raw['disabledTools']),
      update: UpdatePolicy.fromMap(raw['update']),
      updatedAt: _int(raw['updatedAt']),
      updatedBy: _text(raw['updatedBy'], 128),
    );
  }

  Map<String, dynamic> toMap() => {
        'maintenance': {
          'enabled': maintenanceEnabled,
          'blocking': maintenanceBlocking,
          'message': maintenanceMessage,
        },
        'flags': {for (final id in FeatureFlags.all) id: flagOn(id)},
        'disabledTools': (disabledTools.toList()..sort()),
        'update': update.toMap(),
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  AppControl copyWith({
    bool? maintenanceEnabled,
    bool? maintenanceBlocking,
    String? maintenanceMessage,
    Map<String, bool>? flags,
    Set<String>? disabledTools,
    UpdatePolicy? update,
  }) =>
      AppControl(
        maintenanceEnabled: maintenanceEnabled ?? this.maintenanceEnabled,
        maintenanceBlocking: maintenanceBlocking ?? this.maintenanceBlocking,
        maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
        flags: flags ?? this.flags,
        disabledTools: disabledTools ?? this.disabledTools,
        update: update ?? this.update,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      );
}
