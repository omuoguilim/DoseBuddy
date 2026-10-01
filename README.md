# DoseBuddy

DoseBuddy is my medication tracking app, built with Flutter. I started it to make medication schedules, dose check-ins and symptom notes easier to keep together. This version builds on my original purple app and keeps its calendar and adherence screens.

## What you can try

I'm building on the original purple screens, keeping the greeting, calendar and week/month adherence charts.

- Add/edit medication strengths with a unit dropdown. Older free-text entries are preserved.
- Scan a prescription label with the camera or a photo, then review the OCR suggestions before saving. Scanning does not decide your dosing schedule.
- Record taken, missed, intentionally skipped or uncertain doses; correct an entry and retain its earlier state. Not recorded is different from missed.
- Set weekdays, intervals, start/end dates, pauses, archive status and as-needed use. Schedule changes take effect tomorrow so yesterday's records keep their original schedule.
- Browse/search medications, add packaging photos, call saved pharmacy/prescriber numbers and log a new bottle's pill count.
- Log searchable symptoms, severity, onset and duration; use a health journal for measurements and appointment questions.
- Preview/share a PDF with selected medications, due-dose records, optional symptoms and optional patient identity. Sharing does not confirm delivery to a doctor.
- Manage reminder permissions, privacy, timezone and tests. Reminders cover the next 60 scheduled doses and refresh when the app resumes.
- Sign in with verified Firebase email/password. Care Circle has email/verified-phone invitation code; connected medication sharing is still unfinished.

For a quick test, add a made-up medication, record and correct a dose in **Insights → tools → Dose Review**, then compare the calendar and chart. Try the report preview with the patient name switched off. Camera OCR needs native-device testing; an unreadable label should be edited manually. Recognition uses Apple Vision on iOS, ML Kit on Android and Tesseract.js in the portfolio demo. Each platform still needs scanning tests with representative labels.

## Run locally

From the project folder, with Flutter and Xcode installed:

```sh
flutter pub get
dart pub global run flutterfire_cli:flutterfire configure --project=YOUR_FIREBASE_PROJECT --platforms=ios,android
flutter run
```

If your Mac reports a `Flutter.framework` resource-fork code-signing error, try running the project from a folder outside a synced Desktop location. That is a local build issue, not a reason to update this app's dependencies blindly.

## Before a release

This is a development beta. Medication records remain local in Hive without app-level encryption; cloud recovery is not implemented. The Care Circle backend needs deployment and security testing, and it does not yet share medication data or deliver caregiver alerts. Widgets, translations, full account deletion, reconciliation, official pharmacy logos and other approved additions remain outstanding. [FEATURE_STATUS.md](FEATURE_STATUS.md) tracks the gaps explicitly.

GitHub Actions runs Dart analysis, model/parser tests and an unsigned iOS simulator build. Passing those checks does not verify medication safety, notification delivery, OCR quality or Firebase authorization on real devices.

This public repository now contains the current app source. Previous versions remain in commit history; development also continues in my separate private repository. The portfolio demo includes sample records to explore.


## Try DoseBuddy

[Open the demo](https://oluchi-muoguilim.superct3663.chatgpt.site/demos/dosebuddy/index.html).

Explore sample medications, record a dose, compare the charts and download a report. Reset restores the sample records. Demo changes stay in your browser and do not affect a phone account.

You can upload a sample label and review the scan before saving. Notifications require the phone app. Care Circle sharing is not available yet.

For development: `flutter build web --release --dart-define=PORTFOLIO_DEMO=true --base-href /demos/dosebuddy/app/`.
