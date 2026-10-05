import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';
import '../core/app_services.dart';
import '../core/l10n/app_strings.dart';
import '../core/settings/settings_controller.dart';
import '../utils/navigation.dart';
import '../widgets/brand_logo.dart';
import '../widgets/page_body.dart';
import 'account/account_widgets.dart';
import 'home/customize_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<String> _version(String label) async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '$label ${info.version} (${info.buildNumber})';
    } catch (_) {
      return label;
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
    final s = AppStrings.of(context);
    final settings = SettingsScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    Widget tile(IconData icon, String title, VoidCallback onTap,
        {String? subtitle}) {
      return ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
    }

    Widget label(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(t, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.moreTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 12),
            const Center(child: BrandLogo(size: 88)),
            const SizedBox(height: 14),
            Center(
              child: Text(
                s.appName,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: FutureBuilder<String>(
                future: _version(s.version),
                builder: (context, snap) => Text(
                  snap.data ?? s.version,
                  style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 8),
            label(s.accountTitle),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AccountCard(),
            ),
            label(s.appearance),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.theme, style: text.bodyMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: ThemeMode.system, label: Text(s.themeSystem)),
                        ButtonSegment(value: ThemeMode.light, label: Text(s.themeLight)),
                        ButtonSegment(value: ThemeMode.dark, label: Text(s.themeDark)),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (v) => settings.setThemeMode(v.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(s.language, style: text.bodyMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      // Language names are always shown in their own language.
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('English')),
                        ButtonSegment(value: 'hi', label: Text('हिन्दी')),
                      ],
                      selected: {settings.languageCode},
                      onSelectionChanged: (v) => settings.setLanguage(v.first),
                    ),
                  ),
                ],
              ),
            ),
            label(s.dataStorage),
            tile(
              Icons.tune_rounded,
              s.customizeHome,
              () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HomeCustomizeScreen(),
                ),
              ),
              subtitle: s.customizeHint,
            ),
            tile(
              Icons.cleaning_services_outlined,
              s.clearCache,
              () async {
                final messenger = ScaffoldMessenger.of(context);
                await AppScope.of(context).clearCache();
                messenger.showSnackBar(SnackBar(content: Text(s.cacheCleared)));
              },
              subtitle: s.clearCacheHint,
            ),
            const Divider(height: 24),
            tile(Icons.info_outline_rounded, s.aboutApp, () {
              showAboutDialog(
                context: context,
                applicationName: AppInfo.appName,
                applicationIcon: const BrandLogo(size: 48),
                children: const [Text(AppInfo.aboutText)],
              );
            }),
            tile(Icons.privacy_tip_outlined, s.privacyPolicy,
                () => openPage(context, s.privacyPolicy, AppInfo.privacyUrl)),
            tile(Icons.description_outlined, s.terms,
                () => openPage(context, s.terms, AppInfo.termsUrl)),
            tile(Icons.mail_outline_rounded, s.contact,
                () => openPage(context, s.contact, AppInfo.contactUrl)),
            tile(Icons.share_outlined, s.shareApp,
                () => Share.share(AppInfo.shareText)),
            tile(Icons.star_outline_rounded, s.rateApp, _rate),
          ],
        ),
      ),
    );
  }
}
