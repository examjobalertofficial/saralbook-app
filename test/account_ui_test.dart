import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/app_services.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/core/auth/cloud_sync.dart';
import 'package:app/core/cache/cache_store.dart';
import 'package:app/core/expense/currency.dart';
import 'package:app/core/config/config_controller.dart';
import 'package:app/core/feed/feed_repository.dart';
import 'package:app/core/home/home_layout.dart';
import 'package:app/core/home/recents_controller.dart';
import 'package:app/core/personal/cloud_collection.dart';
import 'package:app/core/personal/personal_data.dart';
import 'package:app/core/l10n/app_strings.dart';
import 'package:app/core/settings/settings_controller.dart';
import 'package:app/screens/account/account_widgets.dart';

import 'fakes/fake_auth_backend.dart';

Future<(AppServices, FakeAuthBackend)> _services({bool configured = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = CacheStore(prefs);
  final backend = FakeAuthBackend(configured: configured);
  final auth = AuthController.ready(backend);
  final settings = await SettingsController.load();
  final layout = HomeLayoutController.load(prefs);
  final services = AppServices(
    settings: settings,
    cache: cache,
    config: ConfigController(cache),
    feeds: FeedRepository(cache),
    layout: layout,
    rates: RateService(cache: cache, prefs: prefs),
    sync: CloudProfileSync(auth: auth, settings: settings, layout: layout), // not started: no Firebase in tests
    recents: RecentsController.load(prefs),
    auth: auth,
    personal: PersonalDataHub(auth, (uid, name) => MemoryCollection()),
  );
  await services.auth.init();
  return (services, backend);
}

Widget _host(AppServices services, Widget child, {Locale locale = const Locale('en')}) => AppScope(
      services: services,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets('signed out: shows the sign-in button and the "no login needed" message', (tester) async {
    final (services, _) = await _services();
    await tester.pumpWidget(_host(services, const AccountCard()));
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.textContaining('works without signing in'), findsOneWidget);
  });

  testWidgets('tapping sign in shows name and email, then sign out returns', (tester) async {
    final (services, backend) = await _services();
    await tester.pumpWidget(_host(services, const AccountCard()));

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    await tester.pump();

    expect(backend.signInCalls, 1);
    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.text('asha@gmail.com'), findsOneWidget);
    expect(find.text('Switch account'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of this account? Your data stays safe in the cloud.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(backend.signOutCalls, 1);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('asha@gmail.com'), findsNothing);
  });

  testWidgets('when sign-in is not set up, the app shows a calm message (no button)', (tester) async {
    final (services, _) = await _services(configured: false);
    await tester.pumpWidget(_host(services, const AccountCard()));
    expect(find.text('Sign-in is not available in this version right now.'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('Hindi labels', (tester) async {
    final (services, _) = await _services();
    await tester.pumpWidget(_host(services, const AccountCard(), locale: const Locale('hi')));
    expect(find.text('Google से साइन इन करें'), findsOneWidget);
  });

  testWidgets('requireSignIn opens the sheet when signed out and completes after sign-in', (tester) async {
    final (services, _) = await _services();
    bool? outcome;
    await tester.pumpWidget(_host(
      services,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => outcome = await requireSignIn(context),
          child: const Text('Use feature'),
        ),
      ),
    ));

    await tester.tap(find.text('Use feature'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in required'), findsOneWidget);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();
    expect(outcome, isTrue);
    expect(find.text('Sign in required'), findsNothing);
  });

  testWidgets('requireSignIn returns true immediately when already signed in', (tester) async {
    final (services, _) = await _services();
    await services.auth.signIn();
    bool? outcome;
    await tester.pumpWidget(_host(
      services,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => outcome = await requireSignIn(context),
          child: const Text('Use feature'),
        ),
      ),
    ));
    await tester.tap(find.text('Use feature'));
    await tester.pumpAndSettle();
    expect(outcome, isTrue);
    expect(find.text('Sign in required'), findsNothing);
  });
}
