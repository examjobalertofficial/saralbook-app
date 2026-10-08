import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/cache/cache_store.dart';
import 'package:app/core/expense/currency.dart';

class FakeProvider implements RateProvider {
  FakeProvider(this.rates);
  Map<String, double> rates;
  bool fail = false;
  int calls = 0;

  @override
  Future<Map<String, double>> fetchPerInr() async {
    calls++;
    if (fail) throw const FormatException('offline');
    return rates;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late CacheStore cache;
  late DateTime now;
  late FakeProvider provider;

  RateService make() => RateService(cache: cache, prefs: prefs, provider: provider, now: () => now);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 7, 12);
    cache = CacheStore(prefs, now: () => now);
    provider = FakeProvider({'USD': 0.0125, 'EUR': 0.0108});
  });

  group('parseRates', () {
    test('keeps supported currencies with valid numbers', () {
      final r = parseRates('{"result":"success","rates":{"USD":0.012,"EUR":0.011,"XXX":5,"GBP":-1,"AED":"x"}}');
      expect(r.keys.toSet(), {'USD', 'EUR'});
    });

    test('rejects unusable answers', () {
      for (final bad in ['not json', '[]', '{"result":"error"}', '{"result":"success"}', '{"rates":{"XXX":1}}']) {
        expect(() => parseRates(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('RateService', () {
    test('rupees are always 1:1', () {
      final s = make();
      expect(s.inrPerUnit('INR'), 1.0);
      expect(s.sourceOf('INR'), RateSource.base);
    });

    test('unknown before any refresh', () {
      final s = make();
      expect(s.inrPerUnit('USD'), isNull);
      expect(s.sourceOf('USD'), RateSource.none);
      expect(s.convert(10, 'USD', 'INR'), isNull);
      expect(s.toInrMinor(1000, 'USD'), isNull);
    });

    test('live rates after refresh', () async {
      final s = make();
      await s.refresh();
      expect(s.inrPerUnit('USD'), closeTo(80.0, 0.001)); // 1 / 0.0125
      expect(s.sourceOf('USD'), RateSource.live);
      expect(s.convert(10, 'USD', 'INR'), closeTo(800.0, 0.01));
      expect(s.convert(800, 'INR', 'USD'), closeTo(10.0, 0.001));
      expect(s.toInrMinor(10000, 'USD'), 800000); // $100.00 -> Rs 8,000.00
      expect(s.updatedAt, now);
    });

    test('a fresh copy is not downloaded again', () async {
      final s = make();
      await s.refresh();
      await s.refresh();
      expect(provider.calls, 1);
      await s.refresh(force: true);
      expect(provider.calls, 2);
    });

    test('saved rates are used offline after a restart (last known)', () async {
      await make().refresh();
      now = now.add(const Duration(days: 3)); // stale, but usable
      provider.fail = true;
      final restarted = make()..loadCached();
      expect(restarted.inrPerUnit('USD'), closeTo(80.0, 0.001));
      expect(restarted.sourceOf('USD'), RateSource.lastKnown);
      await restarted.refresh();
      expect(restarted.lastRefreshFailed, isTrue);
      expect(restarted.inrPerUnit('USD'), closeTo(80.0, 0.001)); // still there
    });

    test('rates older than 30 days are not trusted', () async {
      await make().refresh();
      now = now.add(const Duration(days: 40));
      final restarted = make()..loadCached();
      expect(restarted.inrPerUnit('USD'), isNull);
    });

    test('manual rate always wins and survives a restart', () async {
      final s = make();
      await s.refresh();
      await s.setManual('USD', 90);
      expect(s.inrPerUnit('USD'), 90);
      expect(s.sourceOf('USD'), RateSource.manual);
      expect(s.toInrMinor(10000, 'USD'), 900000);

      final restarted = make();
      expect(restarted.manualRate('USD'), 90);
      expect(restarted.inrPerUnit('USD'), 90);

      await restarted.setManual('USD', null);
      expect(restarted.sourceOf('USD'), RateSource.none); // nothing live loaded in this instance
    });

    test('manual rate works with no internet at all', () async {
      final s = make();
      await s.setManual('EUR', 95.5);
      expect(s.convert(2, 'EUR', 'INR'), closeTo(191, 0.001));
    });

    test('bad manual values are ignored', () async {
      final s = make();
      await s.setManual('USD', -5);
      await s.setManual('USD', 0);
      expect(s.manualRate('USD'), isNull);
      await s.setManual('INR', 5);
      expect(s.inrPerUnit('INR'), 1.0);
    });

    test('a failing provider never throws and keeps older rates', () async {
      final s = make();
      await s.refresh();
      provider.fail = true;
      await s.refresh(force: true);
      expect(s.lastRefreshFailed, isTrue);
      expect(s.inrPerUnit('USD'), closeTo(80.0, 0.001));
      expect(s.sourceOf('USD'), RateSource.lastKnown);
    });

    test('tiny amounts never round to zero', () async {
      final s = make();
      await s.refresh();
      expect(s.toInrMinor(1, 'JPY'), isNull); // no JPY rate in this fake
      provider.rates = {'JPY': 0.5};
      await s.refresh(force: true);
      expect(s.toInrMinor(1, 'JPY'), 2); // 1 paise-unit * 2 INR/JPY
    });
  });
}
