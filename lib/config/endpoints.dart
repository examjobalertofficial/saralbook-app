/// Every backend address the app talks to (besides the websites themselves,
/// which live in websites.dart). Change addresses here only.
class Endpoints {
  /// Remote configuration served by the "SaralBook App Config" WordPress plugin.
  /// If this address does not exist yet, the app simply uses built-in defaults.
  static const String configUrl =
      'https://saralbook.com/wp-json/saralbook/v1/config';

  /// Default Home feeds (standard WordPress REST API, no plugin needed).
  static const String examJobAlertPosts =
      'https://examjobalert.com/wp-json/wp/v2/posts?per_page=6';
  static const String saralBookPosts =
      'https://saralbook.com/wp-json/wp/v2/posts?per_page=6';

  /// Remote configuration and feeds may only point to these domains
  /// (and their subdomains). This stops a hacked config from sending
  /// users to a malicious site.
  static const List<String> allowedDomains = [
    'saralbook.com',
    'examjobalert.com',
    'onlinecalcy.com',
  ];

  /// Free exchange rates (no key). 1 INR = x of each currency.
  static const String ratesUrl = 'https://open.er-api.com/v6/latest/INR';

  static const Duration requestTimeout = Duration(seconds: 8);
}
