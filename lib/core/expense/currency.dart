import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/endpoints.dart';
import '../cache/cache_store.dart';

class Currency {
  final String code;
  final String symbol;
  final String name;
  const Currency(this.code, this.symbol, this.name);
}

/// Rupees (INR) are the base currency. Others are converted to rupees.
const List<Currency> supportedCurrencies = [
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('SAR', 'SAR', 'Saudi Riyal'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('JPY', '¥', 'Japanese Yen'),
];

/// Where live rates come from. Replace this class to change provider.
abstract class RateProvider {
  /// Units of each currency you get for 1 rupee, e.g. {'USD': 0.0119}.
  Future<Map<String, double>> fetchPerInr();
}

/// Free provider without an API key (updates about once a day).
/// Response shape: {"result":"success","rates":{"USD":0.0119,...}}
class OpenErApiProvider implements RateProvider {
  OpenErApiProvider({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  @override
  Future<Map<String, double>> fetchPerInr() async {
    final response = await _client.get(Uri.parse(Endpoints.ratesUrl)).timeout(Endpoints.requestTimeout);
    if (response.statusCode != 200) throw const FormatException('rates: bad status');
    return parseRates(utf8.decode(response.bodyBytes, allowMalformed: true));
  }
}

/// Keeps only supported currencies with a sensible positive number.
/// Throws FormatException when the answer is not usable.
Map<String, double> parseRates(String body) {
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic> || (json['result'] != null && json['result'] != 'success')) {
    throw const FormatException('rates: not success');
  }
  final raw = json['rates'];
  if (raw is! Map) throw const FormatException('rates: missing');
  final out = <String, double>{};
  for (final c in supportedCurrencies) {
    if (c.code == 'INR') continue;
    final v = raw[c.code];
    if (v is num && v.isFinite && v > 0) out[c.code] = v.toDouble();
  }
  if (out.isEmpty) throw const FormatException('rates: empty');
  return out;
}

enum RateSource { base, manual, live, lastKnown, none }

/// Exchange rates: live when online, the last saved ones offline, and a manual
/// rate the person can type in (a manual rate always wins).
class RateService extends ChangeNotifier {
  RateService({
    required CacheStore cache,
    required SharedPreferences prefs,
    RateProvider? provider,
    DateTime Function()? now,
  })  : _cache = cache,
        _prefs = prefs,
        _provider = provider ?? OpenErApiProvider(),
        _now = now ?? DateTime.now {
    _loadManual();
  }

  static const String _cacheKey = 'fx_rates';
  static const String _manualKey = 'fx.manual';
  static const Duration freshFor = Duration(hours: 12);
  static const Duration usableFor = Duration(days: 30);

  final CacheStore _cache;
  final SharedPreferences _prefs;
  final RateProvider _provider;
  final DateTime Function() _now;

  Map<String, double> _perInr = {};
  DateTime? _fetchedAt;
  final Map<String, double> _manual = {}; // rupees per 1 unit
  bool _refreshing = false;
  bool _lastRefreshFailed = false;

  DateTime? get updatedAt => _fetchedAt;
  bool get refreshing => _refreshing;
  bool get lastRefreshFailed => _lastRefreshFailed;
  bool get hasLive => _perInr.isNotEmpty;

  void _loadManual() {
    final raw = _prefs.getString(_manualKey);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in m.entries) {
        final v = e.value;
        if (v is num && v > 0 && v.isFinite) _manual[e.key] = v.toDouble();
      }
    } catch (_) {/* ignore damaged value */}
  }

  /// Loads the saved rates (no internet needed).
  void loadCached() {
    final entry = _cache.read(_cacheKey);
    if (entry == null) return;
    if (_now().difference(entry.savedAt) > usableFor) return;
    try {
      final m = jsonDecode(entry.payload) as Map<String, dynamic>;
      final parsed = <String, double>{
        for (final e in m.entries)
          if (e.value is num && (e.value as num) > 0) e.key: (e.value as num).toDouble(),
      };
      if (parsed.isNotEmpty) {
        _perInr = parsed;
        _fetchedAt = entry.savedAt;
      }
    } catch (_) {/* ignore */}
  }

  /// Asks the provider for fresh rates. Quiet on failure: keeps what we have.
  Future<void> refresh({bool force = false}) async {
    if (_refreshing) return;
    final at = _fetchedAt;
    if (!force && at != null && _now().difference(at) < freshFor) return;
    _refreshing = true;
    _lastRefreshFailed = false;
    notifyListeners();
    try {
      final fresh = await _provider.fetchPerInr();
      _perInr = fresh;
      _fetchedAt = _now();
      await _cache.put(_cacheKey, jsonEncode(fresh));
    } catch (_) {
      _lastRefreshFailed = true;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Rupees you get for 1 unit of [code]; null if unknown.
  double? inrPerUnit(String code) {
    if (code == 'INR') return 1.0;
    final m = _manual[code];
    if (m != null) return m;
    final perInr = _perInr[code];
    if (perInr == null || perInr <= 0) return null;
    return 1 / perInr;
  }

  RateSource sourceOf(String code) {
    if (code == 'INR') return RateSource.base;
    if (_manual.containsKey(code)) return RateSource.manual;
    if (!_perInr.containsKey(code)) return RateSource.none;
    final at = _fetchedAt;
    final fresh = at != null && _now().difference(at) < freshFor && !_lastRefreshFailed;
    return fresh ? RateSource.live : RateSource.lastKnown;
  }

  double? manualRate(String code) => _manual[code];

  /// Sets (or with null removes) the manual rate: rupees for 1 unit.
  Future<void> setManual(String code, double? rupeesPerUnit) async {
    if (code == 'INR') return;
    if (rupeesPerUnit == null || !(rupeesPerUnit > 0) || !rupeesPerUnit.isFinite) {
      _manual.remove(code);
    } else {
      _manual[code] = rupeesPerUnit;
    }
    notifyListeners();
    await _prefs.setString(_manualKey, jsonEncode(_manual));
  }

  /// [amount] of [from] expressed in [to]; null if a rate is missing.
  double? convert(double amount, String from, String to) {
    final f = inrPerUnit(from);
    final t = inrPerUnit(to);
    if (f == null || t == null) return null;
    return amount * f / t;
  }

  /// Minor units (paise) in rupees for an amount in another currency.
  int? toInrMinor(int origMinor, String code) {
    final r = inrPerUnit(code);
    if (r == null) return null;
    final v = (origMinor * r).round();
    return v < 1 ? 1 : v;
  }
}
