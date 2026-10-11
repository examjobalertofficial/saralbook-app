"""Runs automatically in the cloud build after `flutter create`.
Sets app name, INTERNET permission, HTTPS-only traffic, and link handling."""
import pathlib
import re

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = manifest.read_text()

s = re.sub(r'android:label="[^"]*"', 'android:label="SaralBook"', s, count=1)

if "android.permission.INTERNET" not in s:
    s = s.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )
if "usesCleartextTraffic" not in s:
    s = s.replace(
        "<application", '<application\n        android:usesCleartextTraffic="false"', 1
    )

queries = """
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="http"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="mailto"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="whatsapp"/></intent>"""
if "</queries>" in s:
    s = s.replace("</queries>", queries + "\n    </queries>", 1)
else:
    s = s.replace("</manifest>", "<queries>" + queries + "\n    </queries>\n</manifest>")

# Deep links: saralbook://... and https://saralbook.com/app/... open the app.
# Flutter's own link handling is switched off: the app reads links itself.
if "saralbook" not in s.split("<queries>")[0].split("<application")[-1] or "android:scheme=\"saralbook\"" not in s:
    filters = '''
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="saralbook"/>
            </intent-filter>
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="saralbook.com" android:pathPrefix="/app/"/>
            </intent-filter>
        '''
    if 'android:scheme="saralbook"' not in s:
        s = s.replace("</activity>", filters + "</activity>", 1)
manifest.write_text(s)

# iOS display name (used later for iPhone)
plist = pathlib.Path("ios/Runner/Info.plist")
if plist.exists():
    p = plist.read_text()
    p = re.sub(
        r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
        r"\1SaralBook\2",
        p,
    )
    plist.write_text(p)

# Show the application id so the build log proves it is correct
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    f = pathlib.Path(name)
    if f.exists():
        print(name, "->", re.findall(r'applicationId\s*=?\s*"([^"]+)"', f.read_text()))
