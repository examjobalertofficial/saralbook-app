import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app/config/websites.dart';
import 'package:app/core/config/site_check.dart';

void main() {
  test('up, redirect-free 403 and 500 / no answer are told apart', () async {
    final client = MockClient((request) async {
      switch (request.url.host) {
        case 'examjobalert.com':
          return http.Response('', 200);
        case 'saralbook.com':
          return http.Response('', 403);
        case 'test.saralbook.com':
          return http.Response('', 503);
        default:
          throw http.ClientException('no route');
      }
    });
    final result = await checkSites(Websites.all, client: client);
    final byId = {for (final r in result) r.id: r};
    expect(byId['examjobalert']!.ok, isTrue);
    expect(byId['examjobalert']!.code, 200);
    expect(byId['saralbook']!.ok, isTrue); // reachable (protected pages answer 403)
    expect(byId['saralbooktest']!.ok, isFalse);
    expect(byId['saralbooktest']!.code, 503);
    expect(byId['onlinecalcy']!.ok, isFalse);
    expect(byId['onlinecalcy']!.code, isNull);
    expect(result.length, Websites.all.length);
  });
}
