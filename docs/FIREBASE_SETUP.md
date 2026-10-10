# Firebase + Google sign-in setup (one time, about 30 minutes)

You do this once. After that, every GitHub build includes Google sign-in.
**Nothing here is needed to build the app** - without it the app works normally and
simply hides sign-in.

> Your GitHub repository is public, so **never paste passwords, keystores or
> google-services.json into any file**. Only use GitHub *Secrets* (Part C).

---

## Part A - Make your signing key (keystore)

Google sign-in checks a "fingerprint" of the key that signs your app. GitHub makes
a *new random key on every build* unless you give it your own, so this step is
**required**. Make it once, keep it forever.

The easiest way (no installs, works in a phone or PC browser) is Google Cloud Shell:

1. Open https://shell.cloud.google.com and sign in with your Google account.
   Accept the terms; a terminal opens at the bottom.
2. Paste this and press Enter:
   ```
   keytool -genkeypair -v -keystore saralbook-release.jks -alias saralbook \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
3. It asks questions:
   * **Password**: choose a strong one and **write it down**. (Typing is invisible - that is normal.)
   * Your name / organisation / city / state / country code (IN): anything sensible.
   * "Is it correct?" -> `yes`
   * "Key password ... RETURN if same as keystore password" -> just press Enter.
     (So the key password = the same password.)
4. Show the fingerprints:
   ```
   keytool -list -v -keystore saralbook-release.jks -alias saralbook
   ```
   Enter the password. Copy the lines starting **SHA1:** and **SHA256:** somewhere (Notepad).
5. Make the text GitHub needs:
   ```
   base64 -w0 saralbook-release.jks
   ```
   A very long line appears. Select it all and copy it.
6. **Back up the keystore file**: in Cloud Shell click the three dots (...) > Download >
   `saralbook-release.jks`. Keep it and the password somewhere safe (not in GitHub).
   If you lose it you cannot update the app under the same signature.

## Part B - Create the Firebase project

1. Go to https://console.firebase.google.com -> **Create a project** (or Add project).
   Name it `SaralBook`. You can turn Google Analytics **off**.
2. On the project home click the **Android icon** (Add app).
   * Android package name: **`com.saralbook.app`** (exactly)
   * App nickname: SaralBook. Leave SHA empty for now. Click **Register app**.
   * Skip the remaining wizard steps (do not download the file yet) -> Continue to console.
3. Add your fingerprints: top-left gear -> **Project settings** -> scroll to **Your apps**
   -> SaralBook -> **Add fingerprint** -> paste the **SHA1**, Save. Add another and paste the **SHA256**.
4. Turn on Google login: left menu **Build > Authentication** -> Get started ->
   **Sign-in method** -> **Google** -> Enable -> choose a **support email** -> Save.
5. Create the database: **Build > Firestore Database** -> Create database ->
   * Location: **asia-south1 (Mumbai)** (cannot be changed later)
   * Start in **production mode** -> Create.
6. Set the security rules: Firestore -> **Rules** tab -> delete everything -> paste the
   contents of `firebase/firestore.rules` from this repo -> **Publish**.
   (Phase 8 added rules for group expenses. If you set up earlier, paste and publish the new file again, otherwise groups will show "Could not sync".)
7. *Storage (photos, PDFs, voice messages) is for a later phase.* Firebase now asks for the
   Blaze (pay-as-you-go) plan to create Storage; it still has a free allowance. Skip it for now.
8. Download the config: **Project settings > Your apps > SaralBook > google-services.json**
   (download it **after** steps 3 and 4 so it includes the sign-in client).

## Part C - Give the secrets to GitHub

Repository -> **Settings > Secrets and variables > Actions > New repository secret**.
Add these 5 (names must match exactly):

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | the long text from Part A step 5 |
| `KEYSTORE_PASSWORD` | the keystore password |
| `KEY_ALIAS` | `saralbook` |
| `KEY_PASSWORD` | the **same** password as above |
| `GOOGLE_SERVICES_JSON_BASE64` | base64 of google-services.json (below) |

Making `GOOGLE_SERVICES_JSON_BASE64`:
* Windows PowerShell:
  `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\Downloads\google-services.json"))`
* Mac / Linux: `base64 -w0 ~/Downloads/google-services.json`
* Phone or any browser: in Cloud Shell use menu (...) > **Upload**, then
  `base64 -w0 google-services.json`

## Part D - Build and test

1. Actions -> **Build SaralBook APK** -> Run workflow.
2. In the log, the step **Configure Firebase (optional)** should end with
   `Firebase configured for com.saralbook.app`, and **Configure release signing** with
   `Release keystore installed`.
3. Install the new APK. **More** tab -> Account -> **Sign in with Google**.
4. Check: name, photo and email show; **Switch account** lets you pick another Google account;
   **Sign out** returns to the sign-in button. Open Firebase > Authentication > Users:
   your account appears. Firestore > Data: `users/<your id>` appears.

## If something goes wrong

| Problem | Fix |
|---|---|
| Sign-in just closes / "cancelled" after choosing an account | Fingerprint missing or wrong. Re-check Part B step 3 (SHA1 **and** SHA256), then download google-services.json again and update the secret. |
| "serverClientId must be provided" | google-services.json has no web client. Make sure Google sign-in is enabled (Part B step 4), then download the file again. |
| Build says "google-services.json is for ..." | You registered a different package name. It must be `com.saralbook.app`. |
| Build log: "Firebase/Google sign-in is DISABLED" | `GOOGLE_SERVICES_JSON_BASE64` secret is missing or misspelled. |
| App from Play Store cannot sign in, but your APK can | Play re-signs apps. Play Console > Setup > App signing > copy that **SHA-1/SHA-256** into Firebase too. |
| Red banner "Could not sync with the cloud" | Tap it (or More > Cloud sync check). It tests each step and says what to fix. Most often: publish the rules from `firebase/firestore.rules` (Firestore Database > Rules > Publish), or create the Firestore database. |
| "Sign-in is not available in this version" shows | The build had no Firebase file (see above). |

## What gets stored where
* Your Google account is only used to log in. The app never sees your Google password.
* Firestore `users/<your id>`: your name, email, theme, language and Home layout so they
  follow you to a new phone. Notes, to-do, expenses etc. will live under the same folder.
* The security rules allow **only you** to read or write your own `users/<your id>` data.
