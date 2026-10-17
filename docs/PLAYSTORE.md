# Putting SaralBook on Google Play (version 2.1.2)

## 1. Build the file Google wants
1. Upload `saralbook-app-phase19.zip` to GitHub, run **Apply update zip**, then **Build SaralBook APK**.
2. Open the finished run. Under *Artifacts* download **SaralBook-PlayStore-Bundle** (`app-release.aab`).
   Google Play needs this `.aab` file, not the APK. The AAB is also much smaller for users
   (Google sends each phone only what it needs), so the 100 MB APK size is not a problem.
3. Always sign with the same keystore (`KEYSTORE_BASE64` secret). Never lose it.

## 2. Alerts (push notifications) - do once
On **saralbook.com** > Settings > **SaralBook App** > *Push notifications*: paste the OneSignal
**App ID** and save. Install the new app and open it once. Then More > Notifications
(and the Jobs tab) show the switch. Until the App ID is saved, students see no alert switch at all.
Only you (signed in as admin) see a hint on the Jobs tab.

## 3. Play Console checklist
* Create the app: name **SaralBook**, default language, *App*, *Free*.
* **App signing**: accept Play App Signing. Then copy the *App signing key* SHA-256
  (Play Console > Test and release > App signing) and
  1. add it as a second line in your `assetlinks.json` fingerprints (SaralBook App Links plugin),
  2. add it to Firebase > Project settings > your app > Add fingerprint (SHA-1 and SHA-256), so Google sign-in works.
* **Privacy policy URL**: required (the app signs in with Google and stores notes, expenses, groups in Firebase).
  Put a page on saralbook.com and paste its link.
* **Data safety form** - answer: collects *name, email, user IDs* (Google sign-in), *app activity / user content*
  (notes, expenses, group chat) stored in Firebase; encrypted in transit; users can delete their data
  (More > Account). No ads, no data sold. Push notifications use OneSignal (device ID).
* **Content rating**: questionnaire, answer honestly (no violence etc.) - result will be "Everyone".
* **Target audience**: 13+ / general (students). Not primarily for children under 13.
* **Store listing**: short description (80 chars), full description, app icon 512x512,
  feature graphic 1024x500, at least 2 phone screenshots.
* Start with **Internal testing** (add your Gmail), install from the Play link, check sign-in, then
  promote to **Production**. New personal developer accounts must run a closed test with 12+ testers for 14 days first.
* Each new upload needs a bigger build number: this version is `2.1.2+20`; the next must be `+21` or more.

## 4. After release
* Set *Latest build* in the SaralBook App plugin to 20 to nudge old APK users to update.
* Test the invite link (https://saralbook.com/app/join/CODE) from the Play version.
