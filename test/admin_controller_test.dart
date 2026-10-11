import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/auth/auth_backend.dart';
import 'package:app/core/auth/auth_controller.dart';
import 'package:app/core/cache/cache_store.dart';
import 'package:app/core/config/admin_controller.dart';
import 'package:app/core/config/config_controller.dart';
import 'package:app/core/config/control.dart';
import 'package:app/core/config/control_backend.dart';

import 'fakes/fake_auth_backend.dart';

const _owner = AppUser(uid: 'owner1', name: 'Owner', email: 'owner@gmail.com');
const _other = AppUser(uid: 'user2', name: 'Other', email: 'other@gmail.com');

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CacheStore cache;
  late MemoryControlBackend cloud;
  late ConfigController config;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = CacheStore(await SharedPreferences.getInstance());
    cloud = MemoryControlBackend(admins: {'owner1'});
    config = ConfigController(cache, control: cloud);
  });

  Future<AdminController> adminFor(AppUser? user) async {
    final auth = AuthController.ready(FakeAuthBackend(start: user));
    await auth.init();
    final admin = AdminController(auth: auth, backend: cloud, config: config, now: () => DateTime.fromMillisecondsSinceEpoch(5000));
    await _pump();
    return admin;
  }

  test('only an account listed in the cloud is an admin', () async {
    expect((await adminFor(_owner)).isAdmin, isTrue);
    expect((await adminFor(_other)).isAdmin, isFalse);
    expect((await adminFor(null)).isAdmin, isFalse);
  });

  test('a non-admin cannot save anything', () async {
    final admin = await adminFor(_other);
    expect(await admin.save(const AppControl(maintenanceEnabled: true)), isFalse);
    expect(cloud.saveCalls, 0);
    expect(config.maintenance.enabled, isFalse);
  });

  test('an admin saves: the cloud gets who/when and the app uses it at once', () async {
    final admin = await adminFor(_owner);
    final ok = await admin.save(const AppControl(
      maintenanceEnabled: true,
      flags: {'groups': false},
      disabledTools: {'resume_maker'},
      update: UpdatePolicy(minBuild: 20),
    ));
    expect(ok, isTrue);
    expect(cloud.stored['updatedBy'], 'owner1');
    expect(cloud.stored['updatedAt'], 5000);
    expect(config.maintenance.enabled, isTrue);
    expect(config.flagOn('groups'), isFalse);
    expect(config.toolOn('resume_maker'), isFalse);
    config.setCurrentBuild(13);
    expect(config.updateRequired, isTrue);
    config.setCurrentBuild(20);
    expect(config.updateRequired, isFalse);
  });

  test('a failed save changes nothing in the app', () async {
    final admin = await adminFor(_owner);
    cloud.failing = true;
    expect(await admin.save(const AppControl(maintenanceEnabled: true)), isFalse);
    expect(config.maintenance.enabled, isFalse);
  });

  test('reset clears every switch', () async {
    final admin = await adminFor(_owner);
    await admin.save(const AppControl(flags: {'groups': false}));
    expect(config.flagOn('groups'), isFalse);
    expect(await admin.reset(), isTrue);
    expect(config.flagOn('groups'), isTrue);
  });

  test('signing out removes admin rights', () async {
    final backend = FakeAuthBackend(start: _owner);
    final auth = AuthController.ready(backend);
    await auth.init();
    final admin = AdminController(auth: auth, backend: cloud, config: config);
    await _pump();
    expect(admin.isAdmin, isTrue);
    await auth.signOut();
    await _pump();
    expect(admin.isAdmin, isFalse);
  });

  group('everyone gets the saved switches', () {
    test('refreshControl applies what the cloud holds and remembers it', () async {
      cloud.stored = {
        'maintenance': {'enabled': true, 'blocking': false, 'message': 'Soon'},
        'flags': {'group_chat': false},
      };
      await config.refreshControl();
      expect(config.maintenance.message, 'Soon');
      expect(config.flagOn('group_chat'), isFalse);

      // a fresh app start (offline) still has them
      final again = ConfigController(cache, control: MemoryControlBackend()..failing = true)..loadCached();
      expect(again.flagOn('group_chat'), isFalse);
      expect(again.maintenance.enabled, isTrue);
    });

    test('offline keeps the last switches; an empty cloud document clears them', () async {
      cloud.stored = {'flags': {'groups': false}};
      await config.refreshControl();
      cloud.failing = true;
      await config.refreshControl();
      expect(config.flagOn('groups'), isFalse);

      cloud.failing = false;
      cloud.stored = {};
      await config.refreshControl();
      expect(config.flagOn('groups'), isTrue);
    });

    test('a damaged saved copy is ignored', () async {
      await cache.put('control_override', '{not json');
      config.loadCached();
      expect(config.flagOn('groups'), isTrue);
    });
  });
}
