# Admin panel and remote switches (Phase 11)

Two places control the app without a new APK. They work together:

| Where | Best for | Needs |
|---|---|---|
| **WordPress** > SaralBook App | Home content, announcements, planned changes | the plugin `wordpress/saralbook-app-config.php` (v1.1.0) |
| **Admin panel in the app** (More > Admin panel) | Quick emergency switches from your phone | your Google account listed as admin (below) |

Rule when both say something: the app uses the *stricter* one. The Admin panel can turn
things off or ask for an update; it can never re-open something WordPress closed.

## What can be switched
* **Maintenance**: a banner on Home, or a full-screen block (everyone except admins).
* **Features**: Group Expenses, Group chat, Expense Tracker.
* **Tools**: any single tool (ids are shown in the panel; WordPress takes them as a comma list).
* **Updates**: "Must update below build N" (full screen) and "Latest build N" (gentle note on Home).
  The build is the number after + in the version (1.11.0+13 = build 13). Leave 0 for no rule.
  The update button opens your Google Play page unless you give another https address on your sites.
* **Websites**: the panel's "Check all websites now" pings the five sites and shows up/down.

## One-time setup (5 minutes)
1. Firebase console > Firestore Database > Rules: paste `firebase/firestore.rules` and **Publish**.
2. Sign in to the app once with the Google account that will be the owner.
3. Firebase console > Authentication > Users: copy that account's **User UID**.
4. Firestore Database > Data > **Start collection** `admins` > Document ID = the UID you copied >
   add any field (for example `role` = `owner`) > Save.
5. Open the app (More) - **Admin panel** now appears for that account only.
   If it does not show, close and reopen the app.

To add another admin, create another document in `admins` with their UID.
To remove one, delete their document. The app can never create or change `admins` (the rules forbid it).

## Safety
* No secret is stored in the app. Whether you are an admin is decided by the cloud.
* The cloud rules check "is this person in `admins`?" again on every save, so a changed app cannot cheat.
* Everyone can read `appConfig/main` (it holds only switches, never personal data).
* Admins are never locked out by maintenance or update rules, so a wrong switch can be undone.
* Firestore free tier: each app start reads this one small document (50,000 free reads per day).
