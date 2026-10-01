# DoseBuddy implementation status

DoseBuddy is in development. The sections below distinguish available features from work that still needs implementation or device testing.

## Approved UI refresh

- Shared purple/lavender design tokens, consistent white app bars, forms, buttons, cards and typography.
- Main navigation: Today, Medications, Insights, Care Circle, Profile. Calendar lives in Today; the original detailed Home view remains available from Today options.
- Today greeting, due-dose progress, next scheduled dose, direct check-in choices, calendar strip, refill notices and original medication actions.
- Medications search/filter cards, add/scan entry points, saved draft recovery and final medication review. Drafts remain local sensitive data, with the same encryption limitation as existing storage.
- Interactive Insights counts/chart with medication filtering and accessible day selectors. Confirmed missed, skipped and not recorded remain separate. Original detailed analytics are retained.
- Care Circle permission preview and clearer real invitation states. Connected sharing is not available yet.
- Existing dose cards use a purple medication accent; recorded-dose snackbar offers Undo.

## Implemented in code

- Original greeting/header with purple extending behind the status bar.
- Visible Insights and Care Circle navigation.
- Mobile prescription-label OCR with image review, editable suggestions and required confirmation. The parser suggests simple strengths; concentration parsing and automatic pharmacy matching remain incomplete. No automatic dosing schedule is inferred.
- Numeric strength/unit selector on Add and Edit Medication. Legacy entries remain unchanged unless the user explicitly converts them.
- Searchable alphabetical symptom list and severity, retaining original symptom logging.
- First/last-name capture for new profile setup. Existing users without a last name are prompted at login.
- Recent unresolved-dose inbox, taken/missed/skipped/unknown entries, actual time, reason and correction history through the inbox. Original taken/skip/undo controls now use the same correction records.
- PDF preview/share with date range, medication selection, optional identity/symptoms and appointment notes. It contains due scheduled doses (including not-recorded rows) and recorded PRN entries, not a clinically verified report. Per-entry redaction and report graphs remain outstanding; share history is in the journal.
- Locally stored packaging reference photos.
- Medication metadata for prescription/OTC/supplement, pharmacy/prescriber, contact numbers, instructions and refill counts. Pharmacy/prescriber call buttons are in the medication library; official logos remain outstanding.
- Effective-dated schedule settings, weekdays, intervals, start/end dates, pauses, archive and as-needed flag. Changes start tomorrow. Medication library supports archive/search/filter browsing and confirmed as-needed recording.
- Bottle refill history with old/new counts. New bottle replaces the count, not an additive stock operation.
- Private notification text, enable toggle, permission request, test and manually selected home timezone. Next 60 scheduled doses are rebuilt on app resume. This is bounded coverage, not an indefinite background guarantee. Snooze is a single pending ten-minute reminder from Dose Review; subsequent snoozes replace it.
- Verified Firebase email/password authentication and invitation-only Care Circle backend code from earlier work. Backend is not deployed by this branch.

- Health journal with numeric measurement entries, symptom timeline, recorded barrier summaries, persistent appointment notes and report-share history. No clinical interpretation is provided.

## Still required to fulfil the approved scope

- Cloud medication sync, encrypted storage, per-user device stores, conflict resolution and recovery.
- Connected caregiver medication views, least-privilege rules, consent tests, sharing preview, access expiry, audit authorship, caregiver handoff notes and real alerts.
- Account deletion across cloud/local data and invitations; published privacy/retention policies.
- Prescription renewal dates, official bundled pharmacy logos and concentrations.
- Reconciliation after discharge. Profile reminder toggle now controls the actual service; its settings link opens Reminder Health.
- Measurement correction/deletion controls. Symptom logs now accept optional onset and duration.
- Native iOS/Android widgets, translations, isolated practice mode and accessibility QA.
- Report row-level redaction, adherence graphs and export inclusion of measurements.
- Notification cold-launch routing/actions, independent snoozes, travel detection, delivery diagnostics and reliable horizon renewal.
- Complete automated migration/security/integration tests, native simulator/device builds and release signing.
- Privacy-preserving support diagnostics and account session management. In-app help/data information is present; a published privacy policy is not.

## Validation

GitHub checks cover Dart analysis and local model/parser tests. Native simulator checks found a Pods_Runner linker failure and checked-in generated settings with machine-specific paths. Generated settings are removed and clean CocoaPods reintegration is being checked; native compatibility is not yet confirmed. Checks do not test OCR capture/results, push delivery, Firebase rules, PDF visual layout, backend deployment, widgets or physical devices. The app is not ready for a medication-management release.
