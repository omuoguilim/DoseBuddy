const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();
const region = 'us-east1';
const permissions = new Set(['routine', 'history', 'missed_alerts']);

async function verifiedCaller(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const user = await auth.getUser(request.auth.uid);
  if (!user.emailVerified && !user.phoneNumber) {
    throw new HttpsError('permission-denied', 'Verify your account first.');
  }
  return user;
}

// Limit lookup attempts per owner. The result intentionally reveals no user profile.
async function checkRate(uid) {
  const ref = db.collection('careInviteLimits').doc(uid);
  await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(ref);
    const now = Date.now();
    const previous = snap.data() || {};
    const windowStart = previous.windowStart || now;
    const active = now - windowStart < 60 * 60 * 1000;
    const count = active ? (previous.count || 0) : 0;
    if (count >= 10) {
      throw new HttpsError('resource-exhausted', 'Try again later.');
    }
    transaction.set(ref, {windowStart: active ? windowStart : now, count: count + 1});
  });
}

exports.sendCareInvite = onCall({region, enforceAppCheck: true}, async (request) => {
  const owner = await verifiedCaller(request);
  await checkRate(owner.uid);
  const contact = String(request.data?.contact || '').trim();
  const selected = request.data?.permissions;
  if (!Array.isArray(selected) || selected.length === 0 ||
      selected.some((p) => !permissions.has(p))) {
    throw new HttpsError('invalid-argument', 'Choose valid permissions.');
  }
  const byEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contact);
  const byPhone = /^\+[1-9]\d{7,14}$/.test(contact);
  if (!byEmail && !byPhone) {
    throw new HttpsError('invalid-argument', 'Enter an email or a phone number with country code.');
  }
  let recipient;
  try {
    recipient = byEmail ? await auth.getUserByEmail(contact.toLowerCase()) :
      await auth.getUserByPhoneNumber(contact);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  if (!recipient || (byEmail && !recipient.emailVerified)) {
    throw new HttpsError('not-found', 'No verified DoseBuddy account found for this contact.');
  }
  if (recipient.uid === owner.uid) {
    throw new HttpsError('invalid-argument', 'You cannot invite yourself.');
  }
  const doc = db.collection('careInvitations').doc(`${owner.uid}_${recipient.uid}`);
  await db.runTransaction(async (transaction) => {
    const previous = await transaction.get(doc);
    if (previous.exists && (previous.data().status === 'accepted' ||
        (previous.data().status === 'pending' && previous.data().expiresAt.toMillis() > Date.now()))) {
      throw new HttpsError('already-exists', 'This person already has an invitation or access.');
    }
    transaction.set(doc, {
      ownerUid: owner.uid,
      recipientUid: recipient.uid,
      contact: byEmail ? contact.toLowerCase() : contact,
      permissions: [...new Set(selected)],
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 7 * 86400000),
    });
  });
  return {invitationId: doc.id, status: 'pending'};
});

exports.respondToCareInvite = onCall({region, enforceAppCheck: true}, async (request) => {
  const user = await verifiedCaller(request);
  const id = String(request.data?.invitationId || '');
  const accept = request.data?.accept;
  if (!/^[A-Za-z0-9_-]{10,150}$/.test(id) || typeof accept !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Invalid invitation.');
  }
  const ref = db.collection('careInvitations').doc(id);
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    const item = doc.data();
    if (!item || item.recipientUid !== user.uid || item.status !== 'pending' ||
        item.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError('permission-denied', 'This invitation is unavailable.');
    }
    transaction.update(ref, {status: accept ? 'accepted' : 'declined',
      respondedAt: admin.firestore.FieldValue.serverTimestamp()});
  });
  return {status: accept ? 'accepted' : 'declined'};
});

exports.revokeCareInvite = onCall({region, enforceAppCheck: true}, async (request) => {
  const user = await verifiedCaller(request);
  const id = String(request.data?.invitationId || '');
  if (!/^[A-Za-z0-9_-]{10,150}$/.test(id)) {
    throw new HttpsError('invalid-argument', 'Invalid invitation.');
  }
  const ref = db.collection('careInvitations').doc(id);
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(ref);
    if (!doc.exists || doc.data().ownerUid !== user.uid) {
      throw new HttpsError('permission-denied', 'Not your invitation.');
    }
    transaction.update(ref, {status: 'revoked',
      revokedAt: admin.firestore.FieldValue.serverTimestamp()});
  });
  return {status: 'revoked'};
});
