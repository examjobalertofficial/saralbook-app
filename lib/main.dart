import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_info.dart';
import 'core/app_services.dart';
import 'core/l10n/app_strings.dart';
import 'core/links/deep_link.dart';
import 'core/links/link_listener.dart';
import 'core/router/app_router.dart';
import 'core/settings/settings_controller.dart';
import 'screens/groups/groups_home_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/update_required_screen.dart';
import 'widgets/feature_gate.dart';
import 'screens/tools/tool_catalog.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The first picture is drawn at once; the app's services are prepared behind it.
  // If anything is slow or fails, the person sees where and can retry.
  runApp(const _Boot());
}

/// Shows a plain start screen while [AppServices] are prepared, then the app.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  AppServices? _services;
  String _step = 'Starting';
  Object? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_run);
  }

  void _start() {
    setState(() {
      _error = null;
      _step = 'Starting';
    });
    _run();
  }

  Future<void> _run() async {
    final attempt = ++_attempt;
    try {
      final s = await AppServices.create(onStep: (x) {
        if (mounted && attempt == _attempt) setState(() => _step = x);
      }).timeout(const Duration(seconds: 20));
      if (!mounted || attempt != _attempt) return;
      setState(() => _services = s);
    } catch (e) {
      if (!mounted || attempt != _attempt) return;
      setState(() => _error = e);
    }
  }

  Future<void> _resetAndRetry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
    if (mounted) _start();
  }

  @override
  Widget build(BuildContext context) {
    final s = _services;
    if (s != null) return SaralBookApp(services: s);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 96),
                const SizedBox(height: 18),
                const Text('SaralBook', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 22),
                if (_error == null) ...[
                  const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
                  const SizedBox(height: 12),
                  Text('$_step...'),
                ] else ...[
                  const Text('SaralBook could not start.', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Step: $_step\n$_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _start, child: const Text('Try again')),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _resetAndRetry, child: const Text('Reset saved data and try again')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    unawaited(_listenForLinks());
    unawaited(_readBuildNumber());
    widget.services.config.addListener(_syncPush);
    // Push notifications start a few seconds AFTER the app is on screen, so a
    // slow phone never waits for them while opening.
    _pushTimer = Timer(const Duration(seconds: 5), () {
      _pushReady = true;
      _syncPush();
    });
  }

  Timer? _pushTimer;
  bool _pushReady = false;

  /// Starts push notifications as soon as the website settings carry an App ID.
  void _syncPush() {
    if (!_pushReady) return;
    final push = widget.services.push;
    final id = widget.services.config.pushAppId;
    if (push != null && id.isNotEmpty) unawaited(push.configure(id));
  }

  /// The build number lets the owner ask old versions to update.
  Future<void> _readBuildNumber() async {
    try {
      final info = await PackageInfo.fromPlatform();
      widget.services.config.setCurrentBuild(int.tryParse(info.buildNumber) ?? 0);
    } catch (_) {/* unknown build: no update rule applies */}
  }

  StreamSubscription<Uri>? _linkSub;

  /// Links that open the app (group invites, tools, tabs).
  Future<void> _listenForLinks() async {
    final source = PlatformLinkSource();
    final first = await source.initialLink();
    if (first != null) unawaited(_open(first));
    _linkSub = source.links.listen((u) => unawaited(_open(u)));
  }

  Future<void> _open(Uri uri) async {
    final link = parseDeepLink(uri);
    if (link == null) return;
    // wait (at most ~6 s) until the start-up screen is gone
    for (var i = 0; i < 30; i++) {
      final path = _router.routeInformationProvider.value.uri.path;
      if (path != AppRoutes.splash && _router.routerDelegate.navigatorKey.currentState != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    final nav = _router.routerDelegate.navigatorKey.currentState;
    if (!mounted || nav == null) return;
    switch (link) {
      case JoinGroupLink(:final code):
        widget.services.links.setPendingJoin(code);
        nav.push(MaterialPageRoute<void>(builder: (_) => const GroupsHomeScreen()));
      case GroupsLink():
        nav.push(MaterialPageRoute<void>(builder: (_) => const GroupsHomeScreen()));
      case ToolLink(:final toolId):
        for (final e in toolCatalog) {
          if (e.id == toolId) {
            nav.push(MaterialPageRoute<void>(
              builder: widget.services.config.toolOn(e.id) ? e.builder : (_) => const ToolOffScreen(),
            ));
            break;
          }
        }
      case TabLink(:final tab):
        _router.go('/$tab');
    }
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    widget.services.config.removeListener(_syncPush);
    _linkSub?.cancel();
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
              listenable: Listenable.merge([config, widget.services.admin]),
              builder: (context, _) {
                // Owners/admins are never locked out, so they can undo a mistake.
                if (widget.services.admin.isAdmin) return child ?? const SizedBox.shrink();
                final m = config.maintenance;
                if (m.enabled && m.blocking) {
                  return MaintenanceScreen(
                    message: m.message,
                    onRetry: () => config.refresh(force: true),
                  );
                }
                if (config.updateRequired) {
                  return UpdateRequiredScreen(
                    message: config.update.message,
                    url: config.update.target,
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
