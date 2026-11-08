/// Social media pages shown in the More tab, filled in from the website.
class SocialLink {
  final String id;
  final String url;
  const SocialLink(this.id, this.url);
}

/// Allowed websites for each kind of link (a link to any other site is ignored).
const Map<String, List<String>> kSocialHosts = {
  'whatsapp': ['whatsapp.com', 'wa.me'],
  'telegram': ['t.me', 'telegram.me', 'telegram.org'],
  'facebook': ['facebook.com', 'fb.com', 'fb.me'],
  'instagram': ['instagram.com'],
  'x': ['x.com', 'twitter.com'],
  'linkedin': ['linkedin.com'],
  'threads': ['threads.net', 'threads.com'],
};

bool isSocialUrlAllowed(String id, String url) {
  final hosts = kSocialHosts[id];
  if (hosts == null || url.isEmpty || url.length > 500) return false;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
  final h = uri.host.toLowerCase();
  return hosts.any((d) => h == d || h.endsWith('.$d'));
}

/// `{"whatsapp": "https://...", "x": "https://..."}` -> the valid links, in a fixed order.
List<SocialLink> parseSocialLinks(Object? raw) {
  if (raw is! Map) return const [];
  final out = <SocialLink>[];
  for (final id in kSocialHosts.keys) {
    final v = raw[id];
    if (v is String && isSocialUrlAllowed(id, v)) out.add(SocialLink(id, v.trim()));
  }
  return out;
}
