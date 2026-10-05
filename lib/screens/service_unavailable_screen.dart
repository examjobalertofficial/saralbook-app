import 'package:flutter/material.dart';

import '../config/websites.dart';
import '../core/app_services.dart';
import '../core/l10n/app_strings.dart';
import '../utils/navigation.dart';
import '../widgets/offline_view.dart';

/// Shown instead of a website that was switched off remotely.
/// The rest of the app keeps working.
class ServiceUnavailableScreen extends StatelessWidget {
  final Website site;
  const ServiceUnavailableScreen({super.key, required this.site});

  Future<void> _retry(BuildContext context) async {
    final config = AppScope.of(context).config;
    await config.refresh(force: true);
    if (!context.mounted) return;
    final fresh = config.config.siteById(site.id);
    if (fresh != null && fresh.enabled) {
      openWebsite(context, fresh, replace: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(site.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: OfflineView(
        icon: Icons.construction_rounded,
        title: s.serviceUnavailableTitle,
        message: site.unavailableMessage ?? s.serviceUnavailableMessage,
        onRetry: () => _retry(context),
      ),
    );
  }
}
