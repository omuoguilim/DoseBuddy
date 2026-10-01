# DoseBuddy Firebase setup (new, separate project)

This branch prepares verified email sign-in and Care Circle invitations. Do not install it over a device containing important DoseBuddy records until the local-data migration has been tested on a backup. The original app in `main` remains intact.

1. In the Firebase console, create a **new project** for DoseBuddy. Record its **project ID** (no password, service-account JSON, or private key needed here). Authentication → Sign-in method: enable **Email/Password**. Enable **Phone** if family members should be discoverable by verified phone number. Set up Cloud Firestore in a suitable US region.
2. In DoseBuddy's project folder on your Mac, run `dart pub global activate flutterfire_cli` and then `flutterfire configure --project YOUR_PROJECT_ID --platforms ios,android`. Register the app IDs from `ios/Runner.xcodeproj/project.pbxproj` and `android/app/build.gradle.kts`; both still default to `com.example.dosebuddy` and need final unique IDs before release. Reconfigure after any bundle ID change.
3. Run `flutter pub get`, `flutter test`, `flutter analyze`, and `flutter run -d "DoseBuddy Original"`. The FlutterFire CLI generates native configuration. This branch uses `Firebase.initializeApp()` for the mobile platforms; do not run it before configuring the native apps.
4. Register App Check providers for both Firebase apps. The app uses the **debug provider** for a debug build (including the iOS simulator), and DeviceCheck/Play Integrity for release builds. Add your simulator's printed debug token to App Check's debug tokens in the console. Never paste it into GitHub. The callable functions enforce App Check and will reject invites until it is configured.
5. Install the Firebase CLI and sign in on your Mac: `npm install -g firebase-tools`, `firebase login`. In the DoseBuddy folder run `firebase use --add`, choose the new project, then `cd functions && npm install && cd ..`, followed by `firebase deploy --only firestore:rules,functions:care-circle`. Deploying Functions may require switching the project to a paid billing plan; review the console prompt and limits before doing so.
6. Test with **two separate verified accounts**. Invite a registered email, accept from the other account, revoke, and confirm an unregistered email fails. Link a phone number via Care Circle on the second account before testing phone lookup. Check that one account cannot query or edit the other's invitations. Test on a copy of legacy local medication data.

## Current limits

- Care Circle currently manages verified invitations only. It does **not** share medication data or send caregiver alerts. A per-user cloud data model, authorization rules, migration, and caregiver screens are still required. Do not tell users their data is shared yet.
- The app's legacy Hive medication box is on-device, not cloud-backed; another account is blocked from viewing it on the same installation. Uninstalling the app may lose that data. Do not treat the current implementation as backup or sync.
- Google/Facebook sign-in buttons, prescription OCR, full account/data deletion, all notification controls, and end-to-end testing still need work before release.
- Do not put Firebase Admin credentials or service-account keys in the app. The client Firebase configuration identifies the project; private backend credentials belong only on the server.
