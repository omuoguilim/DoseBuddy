# DoseBuddy coordinated rebuild

This branch replaces the prototype UI with a connected local-first app. It is a release candidate for review, not a claim of clinical validation or App Store acceptance.

## Implemented

- One versioned schedule and outcome model for Today, calendar history, counts and reports. Edits apply from their save time. Course end dates are inclusive; paused courses stop generating new doses.
- Decimal amounts with explicit administration units. Daily schedules and as-needed recording have separate behavior.
- Connected medication editing, pause/resume, permanent deletion, supply reconciliation, dose corrections and symptom editing/deletion.
- Atomic encrypted snapshot writes with guarded saves. Migration preserves existing recorded doses and supply counts, verifies the encrypted snapshot, then removes old plaintext boxes. Old unrecorded totals cannot be reconstructed and are explicitly excluded/disclosed. Legacy side-effect payloads and local contact lists remain in the complete JSON export.
- No fake account, password reset, social login, caregiver permissions, interaction checker, analytics preference or weighted health score.
- Device authentication gate, privacy notice, usage guidance, complete local deletion, private notification text and reviewed exports.
- Finite one-shot reminder queue, real timezone lookup, explicit permission requests, foreground record/snooze actions and notification coverage display. iOS uses notification taps; Android also offers action buttons. The app refreshes on open/resume and relevant edits. Only the latest snooze is retained and schedule refresh replaces snoozes.
- One shared green-ink theme, readable type sizes, grouped rows and four connected destinations.
- Real on-device OCR transcribes text into an explicitly unverified draft. It does not guess a dose, strength or schedule. User confirmation is required before saving a scanned draft.
- Android notification receivers, biometric activity/theme, private backup settings and production-signing gate; iOS Face ID purpose text and backup exclusion.

## Validation and remaining release gates

Local Flutter bootstrap was rejected by automatic review after it attempted to reach a cloud metadata endpoint. No local Flutter test, analyzer or native build success is claimed. GitHub workflow runs analysis, tests and an iOS simulator build with Flutter 3.47.2. Review its actual result and resolve any failures before merging.

1. Verify migration on a COPY of a populated prototype install: multiple-dose medications, late/skipped events, deleted medications, symptoms, supply and legacy side effects. Do not test the first upgrade on the sole copy of real records. Keep the same bundle identifier to test in-place migration.
2. Verify reminders on physical iPhone and Android: app terminated, restart, disabled permissions, exact-alarm revocation, Focus/battery restrictions, 12 AM/PM, DST gaps and overlaps, travel, removed times, course expiry, record/skip/correct and queue renewal. This finite scheduler requires regular app opening and is not an unattended indefinite reminder service.
3. Verify app-lock resume, notification launch, biometric cancellation, passcode fallback, OS task-switcher snapshots and interrupted writes. Verify erased data and scheduled alerts are absent after restart. Verify secure-storage/key-loss behavior; never silently reset on key failure.
4. Verify camera/gallery cancellation, denied access, Latin/non-Latin labels, label file cleanup, very long OCR output and complete user verification. Non-Latin OCR is not supported in this version.
5. Verify large text, VoiceOver/TalkBack, long medication names, small screens and iPad share sheets. Review final icons and store screenshots.
6. Resolve and commit pubspec.lock and ios/Podfile.lock using the documented toolchain. Existing lockfiles are preserved until resolution succeeds. The workflow uploads the resolved Dart lock as an artifact.
7. Register production identifiers and signing with the app owner's developer accounts. Android deliberately refuses release with debug signing or without an explicit application ID. Existing development identifiers are retained for migration testing. Choose the App Store identity before public distribution.
8. Review privacy/usage text with the intended launch markets and actual distribution setup. Publish the privacy URL, support URL, accurate privacy labels and store metadata. No claim of HIPAA compliance or regulatory clearance is made.
9. Have a pharmacist/clinician review wording and representative workflows. Do not add dosage recommendations or interaction claims without validated clinical data and appropriate review.

## Local review commands

Use Flutter 3.47.2 (the existing dependency lock already requires Flutter >=3.44).

```sh
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build ios --simulator --debug
```

After tests and the simulator pass, replace the Appetize build and test the website embed. The portfolio continues to point at the earlier build until that upload occurs.

## Deliberate product boundaries

No cloud account, caregiver messaging or drug-interaction service is included. These were removed as recommended by the audit; they require a separately validated backend and authorization model. Medication instructions remain user-entered. Background notification delivery, app-store approval and physical-device behavior cannot be proven through code review alone.
