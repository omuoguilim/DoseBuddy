'use strict';

const {HttpsError} = require('firebase-functions/v2/https');
const {identifier, routine, canAccess, doseChange, CareError} = require('./care-domain');

// Injecting Firebase services lets emulator tests exercise the exact handlers.
function handlers({db, verifiedCaller, timestamp}) {
  const profileRef = uid => db.collection('careProfiles').doc(uid);
  async function access(transaction, actor, ownerUid, permission) {
    if (actor.uid === ownerUid) return;
    const grant = await transaction.get(db.collection('careInvitations').doc(`${ownerUid}_${actor.uid}`));
    if (!canAccess(grant.data(), ownerUid, actor.uid, permission))
      throw new HttpsError('permission-denied', 'This profile is not shared with that permission, or access expired.');
  }
  const wrap = fn => async request => {
    const actor = await verifiedCaller(request);
    try { return await fn(request.data || {}, actor); }
    catch (error) {
      if (error instanceof CareError) throw new HttpsError(error.code, error.message);
      throw error;
    }
  };
  return {
    publishCareProfile: wrap(async (input, actor) => {
      if (!Array.isArray(input.medications) || input.medications.length > 100)
        throw new HttpsError('invalid-argument', 'Share up to 100 medications.');
      const medications = input.medications.map(routine);
      if (new Set(medications.map(m => m.id)).size !== medications.length)
        throw new HttpsError('invalid-argument', 'Duplicate medication IDs.');
      const displayName = String(input.displayName || 'Family member').trim().slice(0, 100);
      await db.runTransaction(async tx => {
        const ref = profileRef(actor.uid);
        const previous = await tx.get(ref);
        if ((previous.data()?.revision || 0) !== input.expectedRevision)
          throw new HttpsError('aborted', 'Profile changed. Refresh before publishing again.');
        tx.set(ref, {ownerUid: actor.uid, displayName, medications,
          revision: input.expectedRevision + 1, updatedAt: timestamp(), sharingEnabled: true});
      });
      return {revision: input.expectedRevision + 1};
    }),
    getCareProfile: wrap(async (input, actor) => {
      const ownerUid = identifier(input.ownerUid);
      return db.runTransaction(async tx => {
        await access(tx, actor, ownerUid, 'routine');
        const ref = profileRef(ownerUid);
        const snap = await tx.get(ref);
        if (!snap.exists || (!snap.data().sharingEnabled && actor.uid !== ownerUid))
          throw new HttpsError('not-found', 'The owner has not published a shared routine.');
        let viewHistory = true, manageDoses = true;
        if (actor.uid !== ownerUid) {
          const grant = (await tx.get(db.collection('careInvitations').doc(`${ownerUid}_${actor.uid}`))).data();
          viewHistory = canAccess(grant, ownerUid, actor.uid, 'history');
          manageDoses = viewHistory && canAccess(grant, ownerUid, actor.uid, 'manage_doses');
        }
        const profile = snap.data();
        const histories = {};
        if (viewHistory) for (const med of (profile.medications || [])) {
          const history = await tx.get(ref.collection('history').doc(med.id));
          histories[med.id] = history.data() || {revision: 0, records: []};
        }
        return {ownerUid, displayName: profile.displayName || 'Family member', medications: profile.medications || [],
          revision: profile.revision || 0, sharingEnabled: profile.sharingEnabled, histories, viewHistory, manageDoses};
      });
    }),
    recordSharedDose: wrap(async (input, actor) => {
      const ownerUid = identifier(input.ownerUid), medicationId = identifier(input.medicationId);
      const requestId = identifier(input.requestId);
      return db.runTransaction(async tx => {
        await access(tx, actor, ownerUid, 'routine');
        await access(tx, actor, ownerUid, 'history');
        await access(tx, actor, ownerUid, 'manage_doses');
        const ref = profileRef(ownerUid);
        const historyRef = ref.collection('history').doc(medicationId);
        const eventRef = historyRef.collection('events').doc(`${actor.uid}_${requestId}`);
        const receipt = await tx.get(eventRef);
        if (receipt.exists) {
          if (receipt.data().medicationId !== medicationId ||
              receipt.data().request !== JSON.stringify({date: input.date, scheduledTime: input.scheduledTime,
                state: input.state, reason: input.reason || '', actualTime: input.actualTime || null}))
            throw new HttpsError('already-exists', 'Request ID already used for a different change.');
          return {revision: receipt.data().revision, duplicate: true};
        }
        const profile = (await tx.get(ref)).data();
        const medication = profile?.medications?.find(m => m.id === medicationId);
        if (!profile?.sharingEnabled || !medication || medication.archived || !medication.times.includes(input.scheduledTime))
          throw new HttpsError('failed-precondition', 'Refresh this routine before recording a dose.');
        const current = (await tx.get(historyRef)).data() || {revision: 0, records: []};
        if (current.revision !== input.expectedRevision)
          throw new HttpsError('aborted', 'Another person updated this record. Refresh and review it first.');
        const change = doseChange(current, input, actor.uid);
        tx.set(historyRef, {revision: change.revision, records: change.records});
        tx.create(eventRef, {...change.event, medicationId, revision: change.revision,
          request: JSON.stringify({date: input.date, scheduledTime: input.scheduledTime,
            state: input.state, reason: input.reason || '', actualTime: input.actualTime || null}),
          createdAt: timestamp()});
        return {revision: change.revision, duplicate: false};
      });
    }),
    stopCareSharing: wrap(async (_input, actor) => {
      // Calls check the profile flag on every read and write; old invitations
      // cannot bypass this switch. Local medication records are not deleted.
      await db.runTransaction(async tx => {
        const grants = await tx.get(db.collection('careInvitations').where('ownerUid', '==', actor.uid));
        if (grants.size > 450) throw new HttpsError('resource-exhausted', 'Contact support to revoke this many grants.');
        tx.set(profileRef(actor.uid), {sharingEnabled: false}, {merge: true});
        for (const grant of grants.docs) if (['pending', 'accepted'].includes(grant.data().status)) {
          tx.update(grant.ref, {status: 'revoked', revokedAt: timestamp()});
        }
      });
      return {sharingEnabled: false};
    }),
    getSharedDoseAudit: wrap(async (input, actor) => {
      const ownerUid = identifier(input.ownerUid), medicationId = identifier(input.medicationId);
      return db.runTransaction(async tx => {
        await access(tx, actor, ownerUid, 'routine');
        await access(tx, actor, ownerUid, 'history');
        const ref = profileRef(ownerUid);
        const profile = (await tx.get(ref)).data();
        if (!profile?.sharingEnabled || !profile.medications.some(m => m.id === medicationId))
          throw new HttpsError('not-found', 'Shared medication unavailable.');
        const events = await tx.get(ref.collection('history').doc(medicationId)
          .collection('events').orderBy('createdAt', 'desc').limit(50));
        return {events: events.docs.map(doc => ({id: doc.id,
          previous: doc.data().previous, entry: doc.data().entry}))};
      });
    }),
  };
}
module.exports = {handlers};
