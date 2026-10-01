# DoseBuddy

I’m building DoseBuddy to keep medication schedules, dose records and symptom notes in one place. I wanted the app to feel personal, so I kept the purple design, time-of-day greeting, calendar and adherence charts as I added more tracking tools.

This repository contains my current **Flutter app for iOS and Android**. The [portfolio demo](https://oluchi-muoguilim.superct3663.chatgpt.site/demos/dosebuddy/index.html) is a separate web build of the Flutter interface with sample records. It does not replace the phone app. Demo mode is disabled on phones.

## What I’ve added

- Medication strengths with a unit dropdown, packaging photos and searchable medication lists.
- Prescription-label scanning with editable suggestions. I use Apple Vision on iOS, ML Kit on Android and Tesseract.js in the browser demo. A scan fills in a draft; it does not choose a dosing schedule.
- Taken, missed, intentionally skipped and uncertain dose records, plus corrections that retain the earlier entry. An unrecorded dose stays distinct from a missed dose.
- Weekday and interval schedules, start/end dates, pauses, archived medications and as-needed use.
- Calendar views and weekly/monthly adherence charts.
- Refill logging, saved pharmacy/prescriber phone numbers and medication notes.
- Searchable symptoms with severity, onset and duration, plus a journal for measurements and appointment questions.
- PDF report previews with selected medications, dose history, optional symptoms and optional patient details.
- Reminder permissions, notification privacy, timezone settings and reminder tests.
- Firebase email/password sign-in and verification.

Schedule changes take effect tomorrow so earlier records keep their original schedule. Reminders cover the next 60 scheduled doses and refresh when the app resumes.

## A quick look around

My favorite way to check the app is to add a sample medication, record a dose and correct it in **Insights → tools → Dose Review**. I then compare the calendar and adherence chart, add a symptom, and preview a report with the patient name hidden.

The browser demo keeps changes in browser storage, and Reset restores its sample records. Phone notifications and connected Care Circle sharing are not available in that demo.

## Run locally

I use Flutter, Xcode for iOS and a configured Firebase project.

```sh
flutter pub get
dart pub global activate flutterfire_cli
dart pub global run flutterfire_cli:flutterfire configure --project=YOUR_FIREBASE_PROJECT --platforms=ios,android
flutter devices
flutter run -d DEVICE_ID
```

For the isolated portfolio build:

```sh
flutter build web --release --dart-define=PORTFOLIO_DEMO=true --base-href /demos/dosebuddy/app/
```

## What I’m still working on

DoseBuddy is a development beta. I have invitation code for email and verified-phone Care Circle requests, but connected medication sharing and caregiver alerts are unfinished. I still need to deploy and test the backend permissions.

Medication records currently stay in local Hive storage without app-level encryption. Cloud recovery, full account deletion, widgets, translations and other release work are tracked in [FEATURE_STATUS.md](FEATURE_STATUS.md). A shared PDF does not confirm that a doctor received it.

My automated checks cover Dart analysis, selected models/parsers and an unsigned simulator build. I still need real-device checks for reminders, scanning and account authorization. I don’t treat a successful build as proof that the app is ready for medical use.

Previous versions remain in the commit history. I also keep a private development repository.
