import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/app_services.dart';
import 'package:app/core/auth/auth_backend.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/core/config/admin_controller.dart';
import 'package:app/core/config/control_backend.dart';
import 'package:app/core/auth/cloud_sync.dart';
import 'package:app/core/cache/cache_store.dart';
import 'package:app/core/config/config_controller.dart';
import 'package:app/core/expense/currency.dart';
import 'package:app/core/feed/feed_repository.dart';
import 'package:app/core/groups/group_backend.dart';
import 'package:app/core/groups/group_controllers.dart';
import 'package:app/core/home/home_layout.dart';
import 'package:app/core/home/recents_controller.dart';
import 'package:app/core/l10n/app_strings.dart';
import 'package:app/core/notify/push_backend.dart';
import 'package:app/core/notify/push_controller.dart';
import 'package:app/core/personal/cloud_collection.dart';
import 'package:app/core/personal/personal_data.dart';
import 'package:app/core/settings/settings_controller.dart';
import 'package:app/widgets/job_alerts_card.dart';

import 'fakes/fake_auth_backend.dart';

const _appId = '12345678-1234-1234-1234-123456789abc';

Future<(AppServices, PushController)> _services({required bool withPush, bool owner = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = CacheStore(prefs);
  final auth = AuthController.ready(FakeAuthBackend(
    configured: true,
    start: owner ? const AppUser(uid: 'owner1', name: 'Owner', email: 'o@x.com') : null,
  ));
  await auth.init();
  final config = ConfigController(cache);
  final settings = await SettingsController.load();
  final layout = HomeLayoutController.load(prefs);
  final push = PushController(prefs, backend: _backend);
  final services = AppServices(
    settings: settings,
    cache: cache,
    config: config,
    admin: AdminController(auth: auth, backend: MemoryControlBackend(admins: {'owner1'}), config: config),
    feeds: FeedRepository(cache),
    layout: layout,
    rates: RateService(cache: cache, prefs: prefs),
    sync: CloudProfileSync(auth: auth, settings: settings, layout: layout), // not started: no Firebase in tests
    recents: RecentsController.load(prefs),
    auth: auth,
    personal: PersonalDataHub(auth, (uid, name) => MemoryCollection()),
    groups: GroupsHub(auth, MemoryGroupBackend.new),
    push: withPush ? push : null,
  );
  await Future<void>.delayed(Duration.zero);
  return (services, push);
}

late MemoryPushBackend _backend;

Widget _host(AppServices services) => AppScope(
      services: services,
      child: MaterialApp(
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: JobAlertsCard()),
      ),
    );

void main() {
  setUp(() => _backend = MemoryPushBackend());

  testWidgets('students see nothing until alerts are set up', (tester) async {
    final (services, _) = await _services(withPush: true);
    await tester.pumpWidget(_host(services));
    expect(find.text('Job alerts'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('the owner gets a hint what is missing', (tester) async {
    final (services, _) = await _services(withPush: true, owner: true);
    await tester.pumpWidget(_host(services));
    await tester.pump();
    expect(find.text('Job alerts'), findsOneWidget);
    expect(find.textContaining('OneSignal App ID'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('shows the switch once alerts are available and it turns them off', (tester) async {
    final (services, push) = await _services(withPush: true);
    await push.configure(_appId);
    await tester.pumpWidget(_host(services));
    expect(find.byType(Switch), findsOneWidget);
    expect(push.enabled, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(push.enabled, isFalse);
    expect(_backend.optOutCalls, greaterThan(0));
  });

  testWidgets('a phone without push support shows the note and never crashes', (tester) async {
    final (services, _) = await _services(withPush: false);
    await tester.pumpWidget(_host(services));
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Job alerts'), findsNothing);
  });
}
