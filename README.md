<p align="center"><img src="assets/images/pill_bottle_logo.svg" alt="DoseBuddy logo" width="144"></p>

# DoseBuddy

A Flutter medication tracker for keeping daily schedules, dose records and symptom notes in one place. My first solo app, built around the everyday work of remembering medication and reviewing what happened.

## Project status

The default branch contains the original prototype. The coordinated rebuild is available in [pull request #1](https://github.com/omuoguilim/DoseBuddy/pull/1), which has not been merged. Its encrypted storage, device authentication and revised record system should not be assumed to exist on `main`.

The rebuild's analysis, 18 tests and iOS simulator build passed on its reviewed commit. Physical-device checks and production signing remain release requirements.

## In the prototype

- Medication entry, schedules and course details.
- Dose logging, calendar history and as-needed records.
- Symptom notes and medication-history views.
- Local reminders and prescription-label text recognition.
- Report and emergency-card screens.

Some prototype controls are incomplete. Account, caregiver-sharing and drug-safety screens are not evidence of working cloud services or validated interaction checking. See [the rebuild](https://github.com/omuoguilim/DoseBuddy/pull/1) for the connected replacement workflows.

## Built with

Flutter and Dart; Hive for local records; SharedPreferences; local notifications; Google ML Kit text recognition; image picker and sharing plugins.

## Run locally

Install Flutter and the platform tooling for your device. The committed dependency lock requires a newer SDK than the minimum in the original pubspec; Flutter 3.47.2 was used for the rebuild checks.

```sh
git clone https://github.com/omuoguilim/DoseBuddy.git
cd DoseBuddy
flutter pub get
flutter run
```

For iOS, use a Mac with Xcode, CocoaPods and a configured simulator or device. The Podfile targets iOS 15.5. Camera capture, notifications and authentication need device testing.

To review the rebuild instead:

```sh
git fetch origin
git switch --track origin/dosebuddy/release-rebuild
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

## Where to look

| Path on main | Purpose |
| --- | --- |
| `lib/models/` | Medication, dose and symptom records |
| `lib/today_page.dart` | Daily medication view |
| `lib/calendar_page.dart` | Calendar history |
| `lib/services/` | Notification services |
| `lib/prescription_capture_page.dart` | Prescription-label capture |
| `assets/images/` | DoseBuddy brand assets |

The rebuild uses `lib/core/` and `lib/ui/` instead. Its [release review](https://github.com/omuoguilim/DoseBuddy/blob/dosebuddy/release-rebuild/RELEASE_REVIEW.md) documents migration and device checks.

## Limits

DoseBuddy is a record and reminder project, not a source of dosing instructions or medical advice. Scanned text needs manual verification. Use synthetic records when testing or demonstrating the prototype; do not post private medication information in public issues.
