# SaralBook Student Super App - Architecture

## Folder layout (after Phase 2)
```
lib/
  main.dart                      app start, loads settings, builds MaterialApp.router
  config/                        websites.dart, app_info.dart (Phase 3 adds remote config)
  core/
    l10n/app_strings.dart        GENERATED - edit tool/gen_strings.py (EN + HI)
    router/app_router.dart       every screen address in one place (deep links later)
    settings/settings_controller.dart   theme + language, saved on the phone
  screens/  shell/ tabs/         Home, Study, Jobs, Tools, More + WebView
  theme/app_theme.dart
  widgets/                       reusable pieces
```

## Phase 3 additions
```
config/endpoints.dart             config + feed addresses, allowed domains
core/config/                      remote_config.dart (safe parser), config_controller.dart
core/feed/feed_repository.dart    WordPress posts -> items, caching, offline fallback
core/cache/cache_store.dart       size-limited cache (40 entries)
core/home/                        user's Home layout + recently viewed
core/app_services.dart            everything shared, reached via AppScope.of(context)
```

## Phase 4a: offline tools
```
core/l10n/ltext.dart              LText({'en':..,'hi':..}) for tool content
core/tools/calc_math.dart         formatting, dates, expression parser (pure, tested)
core/tools/calc_model.dart        CalcTool / CalcField / CalcValues (field types, validation)
core/tools/calculators.dart       every calculator = one definition + a compute function
screens/tools/                    generic CalcToolScreen, stopwatch, pomodoro, tools hub
screens/tools/tool_catalog.dart   list of all tools shown in the Tools tab
```
To add a calculator: add a `CalcTool` in `calculators.dart` and put it in
`allCalcTools`. The screen, search, Hindi/English and tests' catalog checks pick it up.
To add a language: add a key to the `LText` maps (falls back to English if missing).

## Phase 4b: PDF & image tools
```
core/tools/files/image_ops.dart    resize, crop, compress-to-KB, sheets (pure Dart + `image`, tested)
core/tools/files/page_ranges.dart  "1-3, 5, 8-" parser (tested)
core/tools/files/photo_check.dart  form-requirement checks (tested)
core/tools/files/pdf_ops.dart      merge/split/compress/convert using pdfrx (needs the phone)
core/files/file_helpers.dart       pick files, write results, save / share
screens/tools/files/               one screen per tool + shared widgets (file_ui.dart)
```
Heavy image work runs in a background isolate. Results are written to a temporary
folder (auto-cleaned after a day) and the user saves or shares them.

## Phase 5: sign-in
```
core/auth/auth_backend.dart       AppUser + AuthBackend interface + scopedKey(uid, key)
core/auth/firebase_backend.dart   Google account -> Firebase Auth (fails safe if not configured)
core/auth/auth_controller.dart    status (checking/unavailable/signedOut/signingIn/signedIn)
core/auth/cloud_sync.dart         users/{uid}: profile + theme/language/Home layout
core/auth/prefs_snapshot.dart     validated cloud preferences
screens/account/account_widgets.dart  AccountCard, SignInSheet, requireSignIn()
tool/configure_firebase.py        CI: adds google-services.json + Gradle plugin (only if secret set)
firebase/*.rules                  Firestore + Storage security rules
```
Rules for later features: personal data lives under `users/{uid}/...` (owner only).
Anything stored on the phone for one account must use `scopedKey(uid, key)` so a second
account on the same phone can never see it.

## Phase 6: personal study data
```
core/personal/models.dart            Note, Todo, Subject, StudyTask, StudySession, Goal, Exam, Favorite
core/personal/logic.dart             search, sorting, progress maths, countdown, note-conflict rule (tested)
core/personal/cloud_collection.dart  CloudCollection interface: Firestore (real) + Memory (tests)
core/personal/collection_controller.dart  live list for the UI, saves without waiting for the server
core/personal/personal_data.dart     PersonalData (one account) + PersonalDataHub (swaps on sign-in/out)
screens/study/                       Notes, To-Do, Planner, Progress, Countdown, Favorites, My data
widgets/favorite_button.dart         bookmark toggle used across the app
```
Firestore paths (all owner-only, see `firebase/firestore.rules`):
`users/{uid}/notes|todos|subjects|study_tasks|study_sessions|goals|exams|favorites`.

How the rules from the brief are met:
* **Offline + sync:** Firestore keeps a copy on the phone, shows changes instantly and sends
  them when the internet returns. Saves never wait for the server.
* **No duplicates:** ids are made on the phone (unique); a favourite's id comes from its address.
* **Conflicts:** a note edited on two phones is never silently overwritten: the later save is kept
  as "(copy)". Other items use last-write-wins (small, simple records).
* **Account separation:** a new `PersonalData` object (new storage paths) is created for each account;
  signing out removes it.
* **Cost:** each signed-in start reads your records once (lists are small). Study sessions are
  limited to the latest 2000.

Not yet built: reminders (to-do / exam alarms) - they arrive with the notifications phase.

## Navigation
Five tabs: Home, Study, Jobs, Tools, More. Bottom bar on phones, side rail on
tablets (width >= 600 and height >= 480). Web pages open on top of the tabs.

## Adding a language
1. Add a column in `tool/gen_strings.py` (`LANGS` + a translation per key).
2. Add the `Locale` is picked up automatically from `LANGS`.
3. Run `python3 tool/gen_strings.py`, add the language button in `more_screen.dart`.

## Firestore schema (Phase 5+)
```
users/{uid}                      profile, prefs, homeLayout, fcmTokens
users/{uid}/notes | todos | plans | favorites | expenses | budgets | recurring | countdowns
groups/{gid}                     name, icon, color, ownerId, adminIds[], memberIds[],
                                 baseCurrency, status (active|archived), inviteCode
groups/{gid}/members/{uid}       role, permissions{}, joinedAt, lastSeen
groups/{gid}/expenses/{eid}      amount, currency, rate, payerId, splits{uid: amount}, version
groups/{gid}/settlements/{sid}   from, to, amount, status (pending|paid|confirmed)
groups/{gid}/messages/{mid}      text/attachment, replyTo, reactions, readBy
groups/{gid}/activity/{aid}      append-only audit log (rules forbid update/delete)
groups/{gid}/budgets | recurring
invites/{code}                   -> gid
```
Security rules: personal data only when `request.auth.uid == uid`; group data
only when `request.auth.uid in group.memberIds`; activity is create-only.
Storage: `users/{uid}/...` and `groups/{gid}/...`, 10 MB cap, content-type checks.

## Release signing (GitHub secrets)
Repository -> Settings -> Secrets and variables -> Actions:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
Without them the build still works but uses the debug key (testing only).
