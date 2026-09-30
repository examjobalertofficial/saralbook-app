import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../utils/navigation.dart';
import '../widgets/brand_logo.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<String> _version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return 'Version ${info.version} (${info.buildNumber})';
    } catch (_) {
      return 'Version 1.0.0';
    }
  }

  Future<void> _rate() async {
    try {
      await launchUrl(
        Uri.parse(AppInfo.playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget tile(IconData icon, String title, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 12),
          const Center(child: BrandLogo(size: 88)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'SaralBook',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: FutureBuilder<String>(
              future: _version(),
              builder: (context, snap) => Text(
                snap.data ?? 'Version',
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          tile(Icons.info_outline_rounded, 'About App', () {
            showAboutDialog(
              context: context,
              applicationName: AppInfo.appName,
              applicationIcon: const BrandLogo(size: 48),
              children: const [Text(AppInfo.aboutText)],
            );
          }),
          tile(Icons.privacy_tip_outlined, 'Privacy Policy',
              () => openPage(context, 'Privacy Policy', AppInfo.privacyUrl)),
          tile(Icons.description_outlined, 'Terms & Conditions',
              () => openPage(context, 'Terms & Conditions', AppInfo.termsUrl)),
          tile(Icons.mail_outline_rounded, 'Contact',
              () => openPage(context, 'Contact', AppInfo.contactUrl)),
          tile(Icons.share_outlined, 'Share App',
              () => Share.share(AppInfo.shareText)),
          tile(Icons.star_outline_rounded, 'Rate App', _rate),
        ],
      ),
    );
  }
}
