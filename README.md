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
