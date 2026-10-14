# SaralBook Android App

This is the Flutter project for the SaralBook app. It opens these five websites inside one app:

1. https://examjobalert.com/
2. https://saralbook.com/
3. https://test.saralbook.com/
4. https://store.saralbook.com/
5. https://onlinecalcy.com/

## Important

You do not need to edit the Dart code just to build the Android APK.

The included GitHub Actions workflow automatically creates the Android and iOS platform folders, configures the Android app name/permissions, installs dependencies, generates the icon/splash screen, checks the project, and builds a release APK and Play Store AAB.

## Easiest way to get the APK

1. Create a GitHub account if you do not already have one.
2. Create a new repository, for example `saralbook-app`.
3. Upload the **contents of this `saralbook` folder** to the repository (the `.github` folder must also be uploaded).
4. Open the repository's **Actions** tab.
5. Select **Build SaralBook APK**.
6. Click **Run workflow** and run it on the `main` branch.
7. Wait for the workflow to finish successfully.
8. Open the completed workflow run.
9. In **Artifacts**, download **SaralBook-APK**.
10. Extract the downloaded artifact and install `app-release.apk` on your Android phone.

## What's new in 1.1.0 (Phase 2)

* New 5-tab navigation: Home, Study, Jobs, Tools, More (rail on tablets)
* Light / Dark / System theme and English / Hindi language (saved on the phone)
* Release signing support (see `docs/ARCHITECTURE.md`) and automated tests
* Full plan and Firestore schema: `docs/ARCHITECTURE.md`

## What's new in 1.2.0 (Phase 3)

* Home is now built from configuration: platforms, latest-post lists, recently viewed
* Pull-to-refresh, skeleton loading, empty / error / offline states, retry
* Saved copies (30 min fresh, 24 h fallback), "Clear cache" in More
* Customize Home: show/hide/reorder sections, reset to default
* Websites can be switched off remotely -> "Service temporarily unavailable"
* Optional WordPress plugin: see `docs/WORDPRESS.md`

## What's new in 1.3.0 (Phase 4a: offline tools)

* Tools tab: search + categories, works fully offline
* 21 calculators (percentage, average, ratio, profit/loss, SI, CI, time & work,
  speed-distance-time, HCF/LCM, fraction, simplification, marks %, CGPA, exam score
  & negative marking, rank/percentile, study time, EMI, GST, unit converter,
  age, date difference) + Age Eligibility (RRB/SSC/Govt)
* Stopwatch (laps) and Pomodoro timer
* All tool text in English and Hindi

## What's new in 1.4.0 (Phase 4b: PDF & image tools, offline)

* PDF: viewer, merge, split / extract pages, compress, page counter,
  PDF -> pictures, pictures -> PDF (powered by pdfrx / PDFium)
* Pictures: compress (to a KB target or quality), resize, crop
* Exam forms: photo resize, signature resize (exact pixels + max KB),
  photo/signature checker, passport photo maker with print sheet (4x6 / A4)
* Results are saved or shared from the app; nothing is uploaded anywhere

## What's new in 1.5.0 (Phase 5: Google sign-in)

* Optional Google sign-in (Firebase Authentication): profile photo, name, email,
  Switch account, Sign out, Google account help links (More tab)
* Nothing requires login; personal features will ask for it with `requireSignIn(context)`
* Theme, language and Home layout follow a signed-in person to any phone
* Security rules for personal data in `firebase/`
* One-time setup guide: `docs/FIREBASE_SETUP.md` (the app builds fine without it)

## What's new in 1.6.0 (Phase 6: study tools)

Sign in with Google (More tab), then in the **Study** tab:

* **Notes** (search, #tags, saves when you go back, never overwrites a change from another phone)
* **To-Do** (priority, due date, overdue, swipe to delete with Undo)
* **Study Planner** (subjects, study tasks, goals) and **Progress** (today / week / month, per subject)
* **Exam Countdown** (date + time, live countdown)
* **Favorites**: bookmark any job, article, result, admit card, mock test, store page or tool
  (bookmark icon in web pages, Home lists and Tools); shown on Home and in Study
* **My data** (More tab): export a copy, or delete everything (type DELETE to confirm)
* Everything works offline and syncs when the internet returns; each account has its own data

## What's new in 1.7.0 (Phase 7: Expense Tracker)

Sign in, then **More > Expense Tracker** (also a summary block on Home):

* Income and expenses, balance and savings, search and filters (type, category, period)
* Default + your own categories (Food, Travel, Shopping, Education, Bills, Health, Entertainment, Other...)
* Budgets: weekly / monthly, overall or per category, warning level, "exceeded" alerts
* Reports: weekly, monthly or custom range; income vs expense, category breakdown, 6-month trend
* Repeating transactions (salary, rent, EMI, subscriptions): daily / weekly / monthly / yearly, pause, edit, stop
* Export to CSV, Excel (.xlsx) or PDF, with filters
* Other currencies with live rates, saved rates offline, or your own rate; plus a Currency Converter tool
* Money is stored in paise (no rounding errors); everything works offline and syncs later

## Website URLs

All five website URLs are centralized in:

`lib/config/websites.dart`

## App information

Privacy, Terms, Contact and Play Store links are in:

`lib/config/app_info.dart`

## Branding

Replace these files later if you want to change the logo/icon:

`assets/branding/logo.png`
`assets/branding/app_icon.png`
`assets/branding/app_icon_foreground.png`

## Android package

The generated Android application ID is:

`com.saralbook.app`

## Build outputs

Release APK:

`build/app/outputs/flutter-apk/app-release.apk`

Play Store bundle:

`build/app/outputs/bundle/release/app-release.aab`

## What's new in 1.8.0 (Phase 8: Group Expenses + Resume Maker)
- **Group Expenses** (More > Group Expenses, or Expense Tracker > Groups): create a group,
  invite with an 8-letter code (share via WhatsApp etc.), roles Owner / Admin / Member,
  bills split equally, by exact amounts or by percentages, several payers, foreign
  currency, simplified "who pays whom", payment confirmation by the receiver, monthly
  group budget, activity history, CSV/PDF export, archive / restore.
- **Resume Maker** (Tools > Student): 5 templates, colour and photo, education / experience /
  skills / personal details / declaration, Hindi text, PDF to share or save. Saved only on the phone.
- **Publish the new Firestore rules** (firebase/firestore.rules) - see docs/FIREBASE_SETUP.md.

## What's new in 1.12.1 (Jobs tab follows the website)
- The **Jobs tab** now shows the Exam Job Alert post lists you set up in WordPress (latest jobs, admit cards, results...),
  the same lists as Home, with pull-to-refresh. Add or reorder them in WordPress > SaralBook App > Home sections; no new APK needed.
- Job alerts switch and the Exam Job Alert website card stay on the tab.

## What's new in 1.12.0 (Phase 12: Alerts, checks, clean-up)
- **Jobs tab**: the "Coming soon" card is replaced by a real **Job alerts** switch (new and updated jobs, admit cards, results).
  It shows a plain note until the OneSignal App ID is set in WordPress > SaralBook App.
- **Update alerts** (new WordPress plugin `wordpress/saralbook-update-alerts.php`): sends a push alert when a post that is already
  published is moved into another category (for example Admit Card) or its title changes. New posts stay with the OneSignal plugin.
- Removed the old "Coming soon" note from the Tools tab (those tools are all here now).
- New automatic check workflow (docs/CI.md): analyse + tests on every branch and pull request, much faster than a full APK build.

## What's new in 1.11.0 (Phase 11: Admin and remote configuration)
- **Admin panel** (More > Admin panel): only for Google accounts you list as admins in the cloud. Nobody else sees it,
  and no password or secret is stored in the app. Switches: maintenance, feature on/off (Group Expenses, Group chat,
  Expense Tracker), turn individual tools off, update rules, and a "check all websites" button.
- **Update rules**: ask old builds to update (full screen) or show a gentle "Update available" note on Home.
- **WordPress** plugin 1.1.0 has the same switches (features, tools, updates) next to the existing ones.
- Owners/admins are never locked out of the app by maintenance or update rules.
- **Publish the updated Firestore rules** (firebase/firestore.rules) and **create your admin document** - see docs/ADMIN.md.

## What's new in 1.10.0 (Phase 10: Deep links + sharing)
- Group invites now share a **tap-to-join link** (`https://saralbook.com/app/join/CODE`) plus the code.
- The app also understands `saralbook://join/CODE`, `saralbook://tool/ID`, `saralbook://tab/NAME`, `saralbook://groups`.
- Opening an invite link takes you straight to Group Expenses > Join with the code filled in.
- For https links to open the app directly, install `wordpress/saralbook-app-links.php` and follow docs/DEEP_LINKS.md.
  The `saralbook://` links work without any setup.

## What's new in 1.9.0 (Phase 9: Group chat)
- New **Chat** tab inside every group: text messages, reply, copy, delete (your own; admins can delete any), unread badge.
- Chat is read-only in archived groups.
- **Publish the updated Firestore rules again** (firebase/firestore.rules) - chat needs them.
