"""Runs in CI after `flutter create`.
1. Patches android/app/build.gradle.kts so release builds use your own key
   when android/key.properties exists (otherwise falls back to the debug key,
   so the build never breaks).
2. If the KEYSTORE_BASE64 secret is set, writes the keystore + key.properties.
Secrets are only read from environment variables and never printed."""
import base64
import os
import pathlib
import re
import sys

gradle = pathlib.Path("android/app/build.gradle.kts")
if not gradle.exists():
    sys.exit("ERROR: android/app/build.gradle.kts not found")
text = gradle.read_text()

if "keystoreProperties" not in text:
    text = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + text

    loader = (
        "val keystoreProperties = Properties()\n"
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    if "android {" not in text:
        sys.exit("ERROR: 'android {' block not found in build.gradle.kts")
    text = text.replace("android {", loader + "android {", 1)

    signing = (
        "    signingConfigs {\n"
        '        create("release") {\n'
        "            if (keystorePropertiesFile.exists()) {\n"
        '                keyAlias = keystoreProperties["keyAlias"] as String\n'
        '                keyPassword = keystoreProperties["keyPassword"] as String\n'
        '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '                storePassword = keystoreProperties["storePassword"] as String\n'
        "            }\n"
        "        }\n"
        "    }\n\n"
    )
    if "    buildTypes {" not in text:
        sys.exit("ERROR: 'buildTypes' block not found in build.gradle.kts")
    text = text.replace("    buildTypes {", signing + "    buildTypes {", 1)

    pattern = r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
    replacement = (
        "signingConfig = if (keystorePropertiesFile.exists()) "
        'signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
    )
    text, n = re.subn(pattern, replacement, text)
    if n != 1:
        sys.exit("ERROR: could not find the release signingConfig line to patch")
    gradle.write_text(text)
    print("Patched build.gradle.kts for release signing")

b64 = os.environ.get("KEYSTORE_BASE64", "").strip()
if not b64:
    print("WARNING: KEYSTORE_BASE64 secret not set -> APK/AAB will be signed "
          "with the DEBUG key (fine for testing, NOT for Play Store updates).")
    sys.exit(0)

required = ("KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")
missing = [k for k in required if not os.environ.get(k)]
if missing:
    sys.exit("ERROR: missing secrets: " + ", ".join(missing))

pathlib.Path("android/app/release.jks").write_bytes(base64.b64decode(b64))
pathlib.Path("android/key.properties").write_text(
    "storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=release.jks\n"
    % (os.environ["KEYSTORE_PASSWORD"], os.environ["KEY_PASSWORD"], os.environ["KEY_ALIAS"])
)
print("Release keystore installed (secrets not printed).")
