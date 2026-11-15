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
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="whatsapp"/></intent>
        <intent><action android:name="android.media.action.IMAGE_CAPTURE"/></intent>"""
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


# Push notifications: Android 13+ permission and a small status-bar icon
# (OneSignal looks for a drawable called ic_stat_onesignal_default).
manifest_text = manifest.read_text()
if "android.permission.POST_NOTIFICATIONS" not in manifest_text:
    manifest_text = manifest_text.replace(
        "<application",
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application',
        1,
    )
    manifest.write_text(manifest_text)
drawable = pathlib.Path("android/app/src/main/res/drawable")
drawable.mkdir(parents=True, exist_ok=True)
(drawable / "ic_stat_onesignal_default.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M13,2L5,13h5l-1,9l8,-11h-5z"/>
</vector>
"""
)

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


# Android lint crashes inside plugin code on the cloud build (a bug in the lint
# tool, "List.removeLast"). Lint is only a code-quality check, so it is switched
# off for release builds. Done two ways so at least one always applies.
_lint_off = """
allprojects {
    tasks.configureEach {
        if (name.startsWith("lintVital") || name.startsWith("lintAnalyze") || name.startsWith("lintReport")) {
            enabled = false
        }
    }
}
"""
_root = pathlib.Path("android/build.gradle.kts")
if _root.exists() and "lintVital" not in _root.read_text():
    _root.write_text(_root.read_text() + "\n" + _lint_off)
    print("Lint disabled in android/build.gradle.kts")

_init = pathlib.Path.home() / ".gradle" / "init.d"
_init.mkdir(parents=True, exist_ok=True)
(_init / "no-lint.gradle").write_text(
    _lint_off.replace("name.startsWith", "name.startsWith").replace(
        "enabled = false", "enabled = false"
    )
)
print("Lint disabled via Gradle init script")


# The Android lint tool in CI crashes inside plugin code (firebase_core,
# "List.removeLast" Java mismatch) and fails the release build. Lint is only a
# quality report, so switch the release-time lint tasks off for every module.
import os

init_dir = pathlib.Path(os.path.expanduser("~/.gradle/init.d"))
init_dir.mkdir(parents=True, exist_ok=True)
(init_dir / "no-lint.gradle").write_text(
    """allprojects {
  tasks.configureEach { t ->
    if (t.name.startsWith("lintVital") || t.name.startsWith("lintAnalyze") || t.name.startsWith("lintReport")) {
      t.enabled = false
    }
  }
}
"""
)
print("Android lint tasks disabled via", init_dir / "no-lint.gradle")
