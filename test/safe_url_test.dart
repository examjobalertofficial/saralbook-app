import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/security/safe_url.dart';

void main() {
  test('allows https links on SaralBook domains and subdomains', () {
    expect(SafeUrl.isAllowed('https://saralbook.com/x'), isTrue);
    expect(SafeUrl.isAllowed('https://test.saralbook.com/'), isTrue);
    expect(SafeUrl.isAllowed('https://examjobalert.com/post'), isTrue);
    expect(SafeUrl.isAllowed('https://onlinecalcy.com'), isTrue);
  });

  test('blocks everything else', () {
    expect(SafeUrl.isAllowed(null), isFalse);
    expect(SafeUrl.isAllowed(''), isFalse);
    expect(SafeUrl.isAllowed('http://saralbook.com'), isFalse);
    expect(SafeUrl.isAllowed('https://evil.com/saralbook.com'), isFalse);
    expect(SafeUrl.isAllowed('https://saralbook.com.evil.com'), isFalse);
    expect(SafeUrl.isAllowed('https://notsaralbook.com'), isFalse);
    expect(SafeUrl.isAllowed('https://user:pw@saralbook.com'), isFalse);
    expect(SafeUrl.isAllowed('javascript:alert(1)'), isFalse);
  });
}
