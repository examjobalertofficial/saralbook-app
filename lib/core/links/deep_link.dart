import 'package:flutter/foundation.dart';

/// Where a link wants to go.
sealed class DeepLink {
  const DeepLink();
}

/// Join a group with its invite code.
class JoinGroupLink extends DeepLink {
  final String code;
  const JoinGroupLink(this.code);
}

/// Open one tool of the Tools tab (by its id).
class ToolLink extends DeepLink {
  final String toolId;
  const ToolLink(this.toolId);
}

/// Go to one of the main tabs: home, study, jobs, tools, more.
class TabLink extends DeepLink {
  final String tab;
  const TabLink(this.tab);
}

/// Open the Group Expenses list.
class GroupsLink extends DeepLink {
  const GroupsLink();
}

/// Address of the website that serves the https links (and the assetlinks file).
const String linkHost = 'saralbook.com';

/// `https://saralbook.com/app/join/ABCD2345` - taps open the app when it is
/// installed, or a small web page that sends people to the Play Store.
String groupInviteLink(String code) => 'https://$linkHost/app/join/$code';

/// The same link with the app's own address (always opens the app).
String groupInviteAppLink(String code) => 'saralbook://join/$code';

const List<String> _tabs = ['home', 'study', 'jobs', 'tools', 'more'];
final RegExp _codePattern = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');

/// Understands:
///   saralbook://join/CODE   saralbook://tool/ID   saralbook://tab/NAME   saralbook://groups
///   https://saralbook.com/app/<the same words>
/// Anything else (other sites, odd words, bad codes) gives null, so a link
/// can never make the app do something unexpected.
DeepLink? parseDeepLink(Uri uri) {
  final List<String> parts;
  if (uri.scheme == 'saralbook') {
    parts = [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments];
  } else if (uri.scheme == 'https' && (uri.host == linkHost || uri.host == 'www.$linkHost')) {
    final segs = uri.pathSegments;
    if (segs.isEmpty || segs.first != 'app') return null;
    parts = segs.sublist(1);
  } else {
    return null;
  }
  final clean = [for (final p in parts) if (p.isNotEmpty) p];
  if (clean.isEmpty) return null;
  switch (clean.first.toLowerCase()) {
    case 'join':
      if (clean.length < 2) return null;
      final code = clean[1].toUpperCase();
      return _codePattern.hasMatch(code) ? JoinGroupLink(code) : null;
    case 'tool':
      if (clean.length < 2 || !RegExp(r'^[a-z0-9_]{1,40}$').hasMatch(clean[1])) return null;
      return ToolLink(clean[1]);
    case 'tab':
      if (clean.length < 2) return null;
      final tab = clean[1].toLowerCase();
      return _tabs.contains(tab) ? TabLink(tab) : null;
    case 'groups':
      return const GroupsLink();
  }
  return null;
}

/// Remembers a link that arrived before its screen could open it
/// (e.g. an invite opened while signed out).
class DeepLinkController extends ChangeNotifier {
  String? _pendingJoinCode;

  String? get pendingJoinCode => _pendingJoinCode;

  void setPendingJoin(String code) {
    _pendingJoinCode = code;
    notifyListeners();
  }

  /// Returns the waiting invite code once and forgets it.
  String? takePendingJoin() {
    final c = _pendingJoinCode;
    _pendingJoinCode = null;
    return c;
  }
}
