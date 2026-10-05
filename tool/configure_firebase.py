"""Runs in CI after `flutter create`.

If the secret GOOGLE_SERVICES_JSON_BASE64 is set:
  * checks it is for com.saralbook.app and has a web OAuth client
  * writes android/app/google-services.json
  * adds the Google Services Gradle plugin to the generated Android project
If the secret is NOT set: does nothing (the app builds fine, sign-in is just
hidden). The secret is only read from the environment and never printed."""
import base64
import json
import os
import pathlib
import re
import sys

EXPECTED_PACKAGE = "com.saralbook.app"
PLUGIN_VERSION = os.environ.get("GOOGLE_SERVICES_PLUGIN_VERSION", "4.4.4")
PLUGIN_ID = "com.google.gms.google-services"

b64 = os.environ.get("GOOGLE_SERVICES_JSON_BASE64", "").strip()
if not b64:
    print("INFO: GOOGLE_SERVICES_JSON_BASE64 is not set -> Firebase/Google sign-in "
          "is DISABLED in this build (the rest of the app works normally).")
    sys.exit(0)

try:
    cfg = json.loads(base64.b64decode(b64))
except Exception:
    sys.exit("ERROR: GOOGLE_SERVICES_JSON_BASE64 is not valid. It must be the "
             "base64 text of google-services.json (see docs/FIREBASE_SETUP.md).")

clients = cfg.get("client", [])
packages = [c.get("client_info", {}).get("android_client_info", {}).get("package_name")
            for c in clients]
if EXPECTED_PACKAGE not in packages:
    sys.exit("ERROR: google-services.json is for %s but this app is %s. "
             "Download the file for the right Android app in Firebase." % (packages, EXPECTED_PACKAGE))

has_web_client = any(o.get("client_type") == 3
                     for c in clients for o in c.get("oauth_client", []))
if not has_web_client:
    print("WARNING: google-services.json has no web OAuth client (client_type 3). "
          "Google sign-in will not work. Enable Google in Firebase > Authentication "
          "> Sign-in method, add your SHA-1, then download the file again.")

target = pathlib.Path("android/app/google-services.json")
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(cfg))

# ---- settings.gradle(.kts): declare the plugin ----
settings = None
for name in ("android/settings.gradle.kts", "android/settings.gradle"):
    if pathlib.Path(name).exists():
        settings = pathlib.Path(name)
        break
if settings is None:
    sys.exit("ERROR: android/settings.gradle(.kts) not found")
text = settings.read_text()
if PLUGIN_ID not in text:
    kts = settings.suffix == ".kts"
    pattern = (r'(id\("com\.android\.application"\)\s+version\s+"[^"]+"\s+apply\s+false)'
               if kts else
               r"""(id\s+["']com\.android\.application["']\s+version\s+["'][^"']+["']\s+apply\s+false)""")
    line = ('\n    id("%s") version "%s" apply false' if kts
            else '\n    id "%s" version "%s" apply false') % (PLUGIN_ID, PLUGIN_VERSION)
    text, n = re.subn(pattern, lambda m: m.group(1) + line, text, count=1)
    if n != 1:
        sys.exit("ERROR: could not find the com.android.application plugin line in " + str(settings))
    settings.write_text(text)
    print("Added", PLUGIN_ID, PLUGIN_VERSION, "to", settings)

# ---- app/build.gradle(.kts): apply the plugin ----
app = None
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    if pathlib.Path(name).exists():
        app = pathlib.Path(name)
        break
if app is None:
    sys.exit("ERROR: android/app/build.gradle(.kts) not found")
text = app.read_text()
if PLUGIN_ID not in text:
    kts = app.suffix == ".kts"
    pattern = (r'(id\("com\.android\.application"\))' if kts
               else r"""(id\s+["']com\.android\.application["'])""")
    line = ('\n    id("%s")' if kts else "\n    id '%s'") % PLUGIN_ID
    text, n = re.subn(pattern, lambda m: m.group(1) + line, text, count=1)
    if n != 1:
        sys.exit("ERROR: could not find the com.android.application plugin line in " + str(app))
    app.write_text(text)
    print("Applied", PLUGIN_ID, "in", app)

print("Firebase configured for", EXPECTED_PACKAGE, "(secret not printed).")
