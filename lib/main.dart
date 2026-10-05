import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'config/app_info.dart';
import 'core/app_services.dart';
import 'core/l10n/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/settings/settings_controller.dart';
import 'screens/maintenance_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  runApp(SaralBookApp(services: services));
}

class SaralBookApp extends StatefulWidget {
  final AppServices services;
  const SaralBookApp({super.key, required this.services});

  @override
  State<SaralBookApp> createState() => _SaralBookAppState();
}

class _SaralBookAppState extends State<SaralBookApp> {
  // Created once so the navigation state survives theme/language changes.
  late final GoRouter _router = createRouter();

  @override
  void initState() {
    super.initState();
    // Quietly fetch the latest configuration; the app does not wait for it.
    unawaited(widget.services.config.refresh());
    // Checks if someone is already signed in (no internet needed).
    unawaited(widget.services.auth.init());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.services.settings;
    final config = widget.services.config;
    return AppScope(
      services: widget.services,
      child: SettingsScope(
        controller: settings,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp.router(
            title: AppInfo.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: AppStrings.supportedLocales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            // Full-screen maintenance message, only if the owner turns it on.
            builder: (context, child) => ListenableBuilder(
              listenable: config,
              builder: (context, _) {
                final m = config.maintenance;
                if (m.enabled && m.blocking) {
                  return MaintenanceScreen(
                    message: m.message,
                    onRetry: () => config.refresh(force: true),
                  );
                }
                return child ?? const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
