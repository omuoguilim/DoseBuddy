# DoseBuddy

A local medication record and reminder app built with Flutter. Today, medication editing, calendar history, symptoms, exports and emergency information use one shared record store.

## Run

Use Flutter 3.47.2 and its bundled Dart SDK.

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

On a Mac with Xcode, build the embedded-demo binary with:

```sh
flutter build ios --simulator --debug
```

The GitHub workflow also builds a simulator artifact for Appetize. Source changes alone do not update the existing website emulator.

## Product boundaries

Records are encrypted on the device. Optional device authentication protects access inside the app. There is no cloud account, caregiver sharing, interaction checker or dose recommendation service.

Daily clock-time schedules and as-needed records are supported. Reminders queue at most 60 future doses over 30 days and must be refreshed by opening the app. Operating-system delivery is not guaranteed. Scanned text is an unverified draft and requires manual checking.

Supply is an estimate. Updating the remaining quantity establishes a fresh baseline; correcting records from before that count does not change the new count. Manually reconcile supply again when necessary.

## Release review

Read [RELEASE_REVIEW.md](RELEASE_REVIEW.md) before distributing an upgrade. It documents migration limitations, physical-device checks, signing and store requirements. This branch is a review candidate, not a clinical validation or app-store approval claim.
