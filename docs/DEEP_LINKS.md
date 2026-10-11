# Deep links (Phase 10)

| Link | Opens |
|---|---|
| `saralbook://join/CODE` or `https://saralbook.com/app/join/CODE` | Group Expenses > Join, code filled in |
| `saralbook://tool/TOOL_ID` | that tool (ids are in `tool_catalog.dart`) |
| `saralbook://tab/home\|study\|jobs\|tools\|more` | that tab |
| `saralbook://groups` | Group Expenses list |

Unknown, malformed or other-site links are ignored (`parseDeepLink`).

## Making https links open the app (Android App Links)
1. Upload `wordpress/saralbook-app-links.php` to `wp-content/plugins/` on saralbook.com and activate it.
2. Find your signing key's SHA-256 (the key that signs the APK you install; Play Console > App integrity if you use Play App Signing, or `keytool -list -v -keystore your.jks`).
3. WordPress > Settings > SaralBook App Links: paste the fingerprint, Save.
4. Open `https://saralbook.com/.well-known/assetlinks.json` - it must show your package `com.saralbook.app` and the fingerprint.
5. Reinstall the new APK. If a link still opens the browser: phone Settings > Apps > SaralBook > Open by default > add links.

If the app is not installed, the link shows a small page with "Open in app" and "Get it on Google Play".
Without these steps, people can still use the code, and `saralbook://` links work immediately.
