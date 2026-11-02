# Shared medication profiles

I added a separate cloud record space so caregivers can view several consenting family members from one signed-in account. The existing on-device Hive box remains private to its owner.

## How it works

1. A verified owner opens Care Circle, then **My shared routine and records**. Publishing requires confirmation and an account matching the local-data owner recorded during login.
2. Publishing uploads medication IDs, names, strengths, current times and archive flags. It does not upload symptom notes, photos, contact details or local dose history. Times are an explicit snapshot; schedule edits require publishing again.
3. The owner invites an existing verified account with routine, history and optionally recording permissions. Recording requires both routine and history. New invitations expire after seven days; accepted access expires after 30 days.
4. The caregiver accepts, then taps the accepted invitation to open that profile. Different accepted invitations open different owners without signing out or replacing local data.
5. An authorized caregiver records or corrects taken/missed/skipped/unknown entries. Shared records begin separately, preserve the previous value in an append-only server event, record the actor and server time, and reject stale revisions. Missing entries are not inferred as missed doses. Actual taking time is left unknown unless supplied, rather than invented from recording time.
6. The owner can revoke one invitation or stop all sharing. Every future request rechecks permission and expiry. Stopping revokes current grants so publishing again does not silently restore old access. Information already viewed cannot be recalled.

## Backend validation

```sh
cd functions
npm ci
npm test
npx firebase emulators:exec --only firestore --project demo-dosebuddy-care 'npm run test:emulator'
```

The integration tests use the Firestore emulator, never a production database. They verify two managed owners, outsiders, routine-only permissions, revocation/expiry, duplicate request IDs, conflicting updates, preserved correction history, and denial of direct Firestore client reads/writes. Test handlers inject verified identities; production handlers additionally use Admin Auth verification and enforce App Check.

## Deployment and phone checks still required

Configure the Firebase project and App Check as described in `FIREBASE_SETUP.md`. Deploy the `care-circle` function codebase and Firestore rules to that intended project only. Functions may require paid billing. No backend was deployed by this change.

Before deployment, run Flutter analysis/tests and a native build. Test two real verified accounts on separate devices: publish, accept, record, correct, refresh, revoke, and verify denied reads after revocation. The shared view uses explicit refresh and clears displayed data after authorization failures; it is not a background sync service. It cannot make already-rendered information disappear from another person's memory or screenshots.

There is a limit of 100 published medications per profile and 500 current shared records per medication. Events preserve correction history independently. Local/cloud history reconciliation, offline caregiver writes, automatic routine updates, remote medication editing, account deletion and caregiver notifications need separate work. Do not describe this implementation as complete device backup or automatic medication synchronization.
