import '../../config/endpoints.dart';

/// Decides whether a web address that came from outside the app
/// (remote config, a feed) is safe to open or fetch.
class SafeUrl {
  static bool isAllowed(String? url) {
    if (url == null || url.isEmpty || url.length > 2000) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    if (uri.userInfo.isNotEmpty) return false;
    final host = uri.host.toLowerCase();
    return Endpoints.allowedDomains.any((d) => host == d || host.endsWith('.$d'));
  }
}
