import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/ltext.dart';
import '../widgets/brand_logo.dart';
import '../widgets/tr.dart';

/// Opens the update page (Google Play or the owner's download page).
Future<void> openUpdatePage(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {/* nothing to do if no browser */}
}

/// Full-screen "please update" shown only when the owner raised the minimum
/// build above this app's build.
class UpdateRequiredScreen extends StatelessWidget {
  final String message;
  final String url;
  const UpdateRequiredScreen({super.key, required this.message, required this.url});

  @override
  Widget build(BuildContext context) {
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
                  tr(context, t('Please update the app', 'कृपया ऐप अपडेट करें')),
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  message.isEmpty
                      ? tr(
                          context,
                          t('This version is too old to keep working. Please install the latest version.',
                              'यह वर्ज़न बहुत पुराना है। कृपया नया वर्ज़न इंस्टॉल करें।'),
                        )
                      : message,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => openUpdatePage(url),
                  icon: const Icon(Icons.system_update_rounded),
                  label: Text(tr(context, t('Update now', 'अभी अपडेट करें'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
