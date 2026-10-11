import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app/config/app_info.dart';
import 'package:app/core/config/control.dart';
import 'package:app/core/config/remote_config.dart';

void main() {
  group('flags and tool ids', () {
    test('only known flags with true/false are kept', () {
      final f = parseFlags({'groups': false, 'group_chat': true, 'hologram': false, 'expense_tracker': 'no'});
      expect(f, {'groups': false, 'group_chat': true});
      expect(parseFlags('nonsense'), isEmpty);
    });

    test('tool ids: list or comma text, bad ids dropped, lower-cased', () {
      expect(parseToolIds(['resume_maker', 'Bad Id!', 5, 'PDF_MERGE']), {'resume_maker', 'pdf_merge'});
      expect(parseToolIds('resume_maker, pdf_merge  stopwatch'), {'resume_maker', 'pdf_merge', 'stopwatch'});
      expect(parseToolIds(null), isEmpty);
    });
  });

  group('UpdatePolicy', () {
    test('must / can update depend on the build number', () {
      const p = UpdatePolicy(minBuild: 10, latestBuild: 13);
      expect(p.mustUpdate(9), isTrue);
      expect(p.mustUpdate(10), isFalse);
      expect(p.canUpdate(12), isTrue);
      expect(p.canUpdate(13), isFalse);
    });

    test('an unknown build (0) is never blocked', () {
      const p = UpdatePolicy(minBuild: 10, latestBuild: 13);
      expect(p.mustUpdate(0), isFalse);
      expect(p.canUpdate(0), isFalse);
    });

    test('update address: own sites and the Play page only, else Google Play', () {
      expect(const UpdatePolicy(url: 'https://saralbook.com/app-download/').target, 'https://saralbook.com/app-download/');
      expect(const UpdatePolicy(url: 'https://evil.example/x').target, AppInfo.playStoreUrl);
      expect(const UpdatePolicy().target, AppInfo.playStoreUrl);
      expect(const UpdatePolicy(url: AppInfo.playStoreUrl).target, AppInfo.playStoreUrl);
    });

    test('numbers from text or negative values are cleaned', () {
      final p = UpdatePolicy.fromMap({'minBuild': '12', 'latestBuild': -4, 'message': '  Hi  '});
      expect(p.minBuild, 12);
      expect(p.latestBuild, 0);
      expect(p.message, 'Hi');
      expect(UpdatePolicy.fromMap('x').isSet, isFalse);
    });
  });

  group('AppControl', () {
    test('round trip through a map', () {
      final c = AppControl.fromMap({
        'maintenance': {'enabled': true, 'blocking': false, 'message': 'Back soon'},
        'flags': {'groups': false},
        'disabledTools': ['resume_maker'],
        'update': {'minBuild': 5},
        'updatedAt': 99,
        'updatedBy': 'u1',
      });
      final again = AppControl.fromMap(jsonDecode(jsonEncode(c.toMap())));
      expect(again.maintenanceEnabled, isTrue);
      expect(again.maintenanceMessage, 'Back soon');
      expect(again.flagOn('groups'), isFalse);
      expect(again.flagOn('group_chat'), isTrue);
      expect(again.disabledTools, {'resume_maker'});
      expect(again.update.minBuild, 5);
      expect(again.updatedBy, 'u1');
    });

    test('garbage gives the empty control', () {
      expect(AppControl.fromMap(null).maintenanceEnabled, isFalse);
      expect(AppControl.fromMap('x').flags, isEmpty);
      expect(AppControl.fromMap({'maintenance': 5, 'flags': 7}).disabledTools, isEmpty);
    });
  });

  group('website config carries flags, tools and update rules', () {
    test('parsed from the WordPress JSON', () {
      final c = AppRemoteConfig.tryParse(jsonEncode({
        'flags': {'groups': false},
        'disabledTools': ['pdf_merge'],
        'update': {'minBuild': 3, 'latestBuild': 4, 'message': 'New!'},
      }))!;
      expect(c.flagOn('groups'), isFalse);
      expect(c.flagOn('group_chat'), isTrue);
      expect(c.toolOn('pdf_merge'), isFalse);
      expect(c.toolOn('stopwatch'), isTrue);
      expect(c.update.latestBuild, 4);
    });

    test('defaults: everything on, no update rules', () {
      final c = AppRemoteConfig.defaults();
      expect(c.flagOn('groups'), isTrue);
      expect(c.toolOn('anything'), isTrue);
      expect(c.update.isSet, isFalse);
    });
  });

  group('owner switches on top of the website (withControl)', () {
    final web = AppRemoteConfig.tryParse(jsonEncode({
      'maintenance': {'enabled': true, 'blocking': true, 'message': 'Site work'},
      'flags': {'groups': false},
      'disabledTools': ['pdf_merge'],
      'update': {'minBuild': 2, 'latestBuild': 3},
    }))!;

    test('an empty control changes nothing', () {
      final m = web.withControl(AppControl.empty);
      expect(m.maintenance.enabled, isTrue);
      expect(m.maintenance.blocking, isTrue);
      expect(m.maintenance.message, 'Site work');
      expect(m.flagOn('groups'), isFalse);
      expect(m.toolOn('pdf_merge'), isFalse);
      expect(m.update.minBuild, 2);
    });

    test('control can switch things off but never re-open what the website closed', () {
      final m = web.withControl(const AppControl(
        maintenanceEnabled: true,
        maintenanceBlocking: false,
        flags: {'groups': true, 'group_chat': false},
        disabledTools: {'stopwatch'},
      ));
      expect(m.maintenance.blocking, isTrue); // website said block: stays blocked
      expect(m.flagOn('groups'), isFalse); // website closed it: stays closed
      expect(m.flagOn('group_chat'), isFalse);
      expect(m.flagOn('expense_tracker'), isTrue);
      expect(m.toolOn('pdf_merge'), isFalse);
      expect(m.toolOn('stopwatch'), isFalse);
    });

    test('control can switch maintenance on and its update rules win', () {
      final m = AppRemoteConfig.defaults().withControl(const AppControl(
        maintenanceEnabled: true,
        maintenanceBlocking: true,
        maintenanceMessage: 'Fixing',
        update: UpdatePolicy(minBuild: 9),
      ));
      expect(m.maintenance.enabled, isTrue);
      expect(m.maintenance.blocking, isTrue);
      expect(m.maintenance.message, 'Fixing');
      expect(m.update.minBuild, 9);
    });
  });
}
