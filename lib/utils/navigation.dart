import 'package:flutter/material.dart';

import '../config/websites.dart';
import '../screens/webview_screen.dart';

/// Opens one of the configured websites inside the app.
/// [replace] = true swaps the current website screen (used by the switcher),
/// so the previous website is closed and memory is released.
void openWebsite(BuildContext context, Website site, {bool replace = false}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => WebViewScreen(
      title: site.name,
      url: site.url,
      currentSiteId: site.id,
    ),
  );
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

/// Opens any page (privacy policy etc.) inside the app.
void openPage(BuildContext context, String title, String url) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WebViewScreen(title: title, url: url, showSwitcher: false),
    ),
  );
}
