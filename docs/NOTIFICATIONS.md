# Notifications (alerts) for SaralBook

Alerts reach phones even when the app is closed or minimised. They need the internet on the phone.
They use OneSignal (free plan). The App ID is public; the REST API Key stays on your website only.

## One-time setup
1. Create a free account at onesignal.com > New App > Google Android (FCM).
   OneSignal asks for the Firebase "service account" key of your Firebase project
   (Firebase console > Project settings > Service accounts > Generate new private key).
2. Copy the **App ID** and the **REST API Key** (OneSignal > Settings > Keys & IDs).
3. WordPress > **SaralBook App** (left menu) > Push notifications: paste the App ID, save.
   The app reads it the next time it starts and shows the alert switch.
4. WordPress > Settings > **SaralBook App Push**: paste App ID + REST API Key, press "Send test notification".
5. Optional: Settings > **SaralBook Update Alerts** for posts that are moved into Admit Card / Result later.
6. If you also use the "OneSignal Push Notifications" WordPress plugin, turn OFF its automatic sending,
   otherwise people get two alerts.

## On the phone
Open the app once, then More > Notifications (or the Jobs tab) > switch on. Allow notifications when Android asks.
To keep one post silent, give it the tag `no-push`.

## If nothing arrives
* The test notification on the website must work first.
* Some phones (Oppo, Vivo, Xiaomi, Realme) stop apps in the background: Settings > Battery > SaralBook > Allow background activity.
