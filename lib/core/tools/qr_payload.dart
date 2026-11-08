/// Builds the text that goes inside a QR code.

String _wifiEscape(String s) => s.replaceAllMapped(RegExp(r'([\;,:"])'), (m) => '\\${m.group(1)}');

/// WiFi login QR. [security] is "WPA", "WEP" or "nopass".
String wifiPayload({required String ssid, String password = '', String security = 'WPA', bool hidden = false}) {
  final open = security == 'nopass' || password.isEmpty;
  final b = StringBuffer('WIFI:T:${open ? 'nopass' : security};S:${_wifiEscape(ssid)};');
  if (!open) b.write('P:${_wifiEscape(password)};');
  if (hidden) b.write('H:true;');
  b.write(';');
  return b.toString();
}

/// UPI payment QR (works with any UPI app).
String upiPayload({required String upiId, String name = '', String amount = '', String note = ''}) {
  final q = <String, String>{'pa': upiId.trim()};
  if (name.trim().isNotEmpty) q['pn'] = name.trim();
  final amt = amount.trim();
  if (amt.isNotEmpty && double.tryParse(amt) != null && double.parse(amt) > 0) q['am'] = amt;
  if (note.trim().isNotEmpty) q['tn'] = note.trim();
  q['cu'] = 'INR';
  return 'upi://pay?${q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
}

/// A UPI id looks like name@bank.
bool isValidUpiId(String s) => RegExp(r'^[\w.\-]{2,256}@[A-Za-z][A-Za-z0-9.\-]{1,64}$').hasMatch(s.trim());
