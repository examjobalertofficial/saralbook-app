import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../widgets/brand_logo.dart';

/// Full-screen message used only when maintenance is set to "blocking".
class MaintenanceScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const MaintenanceScreen({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 80),
                const SizedBox(height: 24),
                Text(
                  s.maintenanceTitle,
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message.isEmpty ? s.maintenanceMessage : message,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(s.tryAgain),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
