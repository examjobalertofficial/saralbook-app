import 'package:flutter/material.dart';

import '../config/websites.dart';
import '../core/app_services.dart';
import '../screens/service_unavailable_screen.dart';
import '../screens/webview_screen.dart';

/// Opens one of the configured websites inside the app.
/// [replace] = true swaps the current website screen (used by the switcher),
/// so the previous website is closed and memory is released.
/// A website switched off remotely shows "Service temporarily unavailable".
void openWebsite(BuildContext context, Website site, {bool replace = false}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (site.enabled) {
    AppScope.of(context).recents.add(site.name, site.url);
  }
  final route = MaterialPageRoute<void>(
    builder: (_) => site.enabled
        ? WebViewScreen(title: site.name, url: site.url, currentSiteId: site.id)
        : ServiceUnavailableScreen(site: site),
  );
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}

/// Opens any page (privacy policy etc.) inside the app.
void openPage(BuildContext context, String title, String url) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => WebViewScreen(title: title, url: url, showSwitcher: false),
    ),
  );
}

/// Opens an article/job from a Home feed and remembers it in "Recently Viewed".
void openFeedItem(BuildContext context, String title, String url) {
  AppScope.of(context).recents.add(title, url);
  openPage(context, title, url);
}
