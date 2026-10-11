import 'dart:async';

import 'package:app_links/app_links.dart';

/// Gives the links that open the app: the one that started it and later ones.
/// Never throws (a phone without link support just gets no links).
abstract class LinkSource {
  Future<Uri?> initialLink();
  Stream<Uri> get links;
}

class PlatformLinkSource implements LinkSource {
  PlatformLinkSource() : _links = AppLinks();
  final AppLinks _links;

  @override
  Future<Uri?> initialLink() async {
    try {
      return await _links.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri> get links => _links.uriLinkStream.handleError((Object _) {});
}
