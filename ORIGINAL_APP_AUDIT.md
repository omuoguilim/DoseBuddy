# DoseBuddy original: feature and release audit

Source: the uploaded original app, preserved in the first source commit of this private repository. Code review as of September 28, 2026. This is a source audit, not a physical-device test or clinical validation. The purple greeting, Today cards, Insights graphs, calendar, side effects, profile, and onboarding are the baseline to keep.

## Existing features to preserve

- Today: personalized morning/afternoon/evening greeting, pill cards, taken/upcoming/missed summary, refill banner, Insights shortcut, drawer.
- Medication workflow: add/edit/delete medications, multiple daily times, mark and unmark taken, notes, supply estimate and refill, side effects dialog/history.
- History: calendar with day status and medication entries; week/month Insights graphs and per-medication summaries; profile statistics and streak.
- Profile and setup: name/photo, onboarding, email form, notification settings/tests, basic CSV share and data deletion.

## Control and behavior audit

| Screen/control | What the source does now | Required behavior before release |
| --- | --- | --- |
| Sign up / log in | Accepts almost any nonempty password and saves the entered email in SharedPreferences; no account is created or authenticated (`lib/auth_page.dart`). | Real verified accounts, sessions, password reset, account deletion; no suggestion that an unverified email is an identity. |
| Forgot password | Displays “reset link sent” without sending one (`lib/auth_page.dart`). | Send a real link through the authentication provider and show an honest error/success state. |
| Facebook / Google | Show “not implemented” (`lib/auth_page.dart`). | Connect and test the provider or hide the controls until available. |
| Scan prescription | Waits two seconds and inserts a hardcoded amoxicillin example (`lib/add_medication_page.dart`). | Camera/photo OCR returning a reviewable draft; never guess dose, schedule or drug name; require confirmation before save. Remove the fake success message. |
| Add medication / refill | Invalid numeric supply can be accepted or cause a null assertion; no sensible bounds on counts (`lib/add_medication_page.dart`). | Validate units, positive quantities, threshold, times and duplicates; keep the screen and styling. |
| Edit medication | Saves new times, then cancels using the **new** times; reminders for removed times can remain (`lib/edit_medication_page.dart`, `lib/services/notification_services.dart`). | Cancel using the prior schedule, then reschedule and verify; preserve historical dose snapshots. |
| Delete medication | Deletes the Hive object without cancelling its pending reminders (`lib/detailpage.dart`). | Cancel only that medication's reminders and confirm what happens to history. Prefer archive/pause when history matters. |
| Mark/unmark taken | Taken records are a mutable list within a medication; undo adds supply back and may overestimate it after refills (`lib/models/medication.dart`, `lib/detailpage.dart`, `lib/square.dart`). | Explicit per-dose records and corrections, actual time, reason, safe inventory reconciliation. Never infer ingestion from opening a notification. |
| Skipped | No explicit skipped record or reason; overdue doses appear “missed.” | Add **Skip** beside Take, capture optional reason, keep Skipped separate from unrecorded/missed, allow correction. |
| Today summary | Counts a single mutable `status` per medication; each scheduled time overwrites it (`lib/homepage.dart`). | Count individual scheduled doses and keep Today, calendar and Insights consistent. |
| Calendar | Stops on December 31, 2026; tapping a dose opens side effects history (`lib/calendar_page.dart`). | Extend dates dynamically, tap a dose for its actual record/correction, keep side effects as a separate action. |
| Insights / adherence graph | Present but includes later doses today in total; all prior dates assume the current schedule since creation (`lib/insights_page.dart`, `lib/models/medication.dart`). | Preserve the purple graph; use only due doses, explicit skipped/missed definitions, historical schedule versions, 7/30/90-day and by-medication drilldown, visible calculation notes. |
| Notification toggles | Drawer and Profile switches only set local widget booleans; Profile resets to `true` when reopened (`lib/homepage.dart`, `lib/profile_page.dart`). | One persisted setting tied to permission, scheduler, and both screens; explain if OS permissions are off. |
| Reminder delivery | Hardcoded `America/New_York`; repeating notifications use `medicationId.hashCode + index`, while tapped/action payloads only print (`lib/services/notification_services.dart`). | Device timezone/DST handling, collision-safe IDs, permission feedback, working snooze/review action, safe resync after edit, travel and reboot checks. |
| Grace period | Profile change exists only in widget state and resets; medication stores a separate value (`lib/profile_page.dart`). | Persist the chosen setting and apply it coherently, with per-med override only if clearly displayed. |
| Refill alert | Shows a low-supply banner based on estimated pills (`lib/homepage.dart`). | Reliable baseline and correction behavior; distinguish an estimate from a verified count. |
| Drawer: Account, Edit Profile, My Medications, Medication History, Privacy Policy, About | Each tap only closes the drawer (`lib/homepage.dart`). | Navigate to a real screen or remove the row until implemented. |
| Profile: Privacy Policy / Help & Support | `onTap: () {}` (`lib/profile_page.dart`). | Real policy and support/help routes. |
| Profile photo | Stores image picker's temporary path (`lib/profile_page.dart`). | Copy image to stable protected app storage and preserve it on upgrade/export as appropriate. |
| Export | Shares a CSV string containing only medication definitions; does not export taken/skip/side effects or escape all CSV fields (`lib/profile_page.dart`). | Explicit full export including records and timestamps, correctly encoded CSV or PDF, review/share confirmation. |
| Clear all data / Log out | Clears medication box only or navigates away; name, email, image path and pending reminders remain (`lib/profile_page.dart`, `lib/homepage.dart`). | Separate log out and irreversible deletion; deletion includes local/remote records, scheduled alerts and account data, with a confirmation. |
| Tests | Only the untouched starter counter test (`test/widget_test.dart`). | Model, migration, notification-plan, security-rule and end-to-end flows covering every control above. |

## Care Circle: exact behavior to build

1. Create real accounts with verified email and/or phone. Store normalized contact identifiers privately. Consider opt-in discoverability and rate limits so lookup cannot enumerate users at scale.
2. In **Care Circle → Add person**, the owner enters an email or phone. Server-side lookup accepts **only a verified existing DoseBuddy account**. If none is eligible, do not add a member or expose any medication data. Explain the result without exposing an account's private details.
3. Send an in-app invitation to that account. Nothing is shared until the recipient accepts. The owner chooses permissions first: view routine, view dose history, receive missed-dose alerts, or help edit. No editing by default.
4. Show Pending / Connected / Declined, resend or cancel, revoke access instantly, and keep an audit trail. Each user must be able to inspect who can see what.
5. Enforce owner and caregiver permissions **on the server** for every read/write; hiding a button in Flutter is insufficient. Test attempts to access another account directly.
6. Define when alerts happen and what they disclose. Do not claim that a lack of a recorded dose proves that a person missed medication. Let each person control lock-screen preview privacy.

## Additions that fit the original design

| Priority | Feature | Acceptance check |
| --- | --- | --- |
| First | Per-dose Taken / Skipped / Not recorded, edit/correct, reason and actual time | Changing one dose updates Today, calendar, Insights, export, notifications and supply exactly once. |
| First | Restore the original purple Insights as the source of truth, with accurate 7/30-day graphs and by-medication view | Graph agrees with the same date's dose records and labels its denominator. |
| First | Genuine OCR or honest manual entry | No medicine or strength appears without verified source/explicit user entry. |
| First | Persisted notification/privacy settings and reliable rescheduling | Every visible toggle survives restart and has a real effect; deleted meds stop reminding. |
| Next | Care Circle with verified invitations and consent, scoped roles, revoke and audit | An unregistered person is never added; an invited account sees nothing until acceptance. |
| Next | Pause/resume, start/end dates, as-needed medication, schedule changes | Past entries remain correct when a routine changes; as-needed doses stay out of scheduled adherence totals. |
| Next | Side-effect/symptom timeline, notes and shareable doctor report | User can review and correct entries; reports identify them as user-entered. |
| Next | Backup/restore, full data export, account/data deletion | No silent data loss on update or device change; export and deletion work on both local and cloud copies. |
| Optional | Refill log, dosage-form support, accessible text sizing, medication list for appointments | No automatic advice to change treatment; all actions usable without long press. |

## Release criteria

- Preserve the original visual screens, navigation and useful actions; compare screenshots before and after on iPhone sizes.
- Migrate existing Hive boxes, taken logs, symptoms and SharedPreferences **non-destructively**. Verify on a copy of real older data before any cleanup.
- Encrypt sensitive local data, store secrets in platform secure storage, authenticate cloud access, minimize shared data, and review server authorization rules.
- Document privacy/data retention/deletion and check applicable rules with qualified counsel before a public release. Do not make clinical claims or offer dose recommendations without appropriate review.
- Run automated tests, iOS and Android device checks, notification permission/DST/offline tests, accessibility checks, privacy review, and a release build. A successful simulator build alone does not prove readiness.
