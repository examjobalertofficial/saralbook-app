# Controlling the app from WordPress (optional)

The app works without this. Without the plugin it shows its built-in Home
(your 5 websites + latest posts from examjobalert.com and saralbook.com).

## Install (5 minutes)
1. Zip the file `wordpress/saralbook-app-config.php` (or upload the PHP file
   into `wp-content/plugins/saralbook-app-config/`).
2. On **saralbook.com** -> Plugins -> Add New -> Upload -> Activate.
3. Open the new **SaralBook App** menu in the dashboard.
4. Check this address opens in a browser and shows text:
   `https://saralbook.com/wp-json/saralbook/v1/config`

If you want the plugin on a different site, change `configUrl` in
`lib/config/endpoints.dart` (one line).

## What you can control (no coding, no new APK)
| Setting | Effect in the app |
|---|---|
| Maintenance | Banner on Home, or full-screen block for emergencies |
| Announcements | Up to 3 cards at the top of Home, optional link |
| Websites on/off | A site that is down shows "Service temporarily unavailable" instead of a broken page |
| Home sections | Order and content of Home: latest-post lists (jobs, admit cards, results, current affairs), platforms, recently viewed, favorites, expense summary |

Admit Cards / Results / Current Affairs: add a "Latest posts" row and paste
the category feed address, e.g.
`https://examjobalert.com/wp-json/wp/v2/posts?categories=12&per_page=6`.

## Safety built into the app
* Only `https` addresses on saralbook.com, examjobalert.com and onlinecalcy.com
  (and their subdomains) are accepted. Anything else in the config is ignored.
* Bad or missing config never crashes the app; it keeps the last good copy
  (up to 7 days) or the built-in defaults.
* Feeds are cached 30 minutes. If a website is down the app shows a saved copy
  (marked "Showing saved copy") for at most 24 hours, never older.
