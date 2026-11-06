const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const admin = require('firebase-admin');
const {HttpsError} = require('firebase-functions/v2/https');
const {initializeTestEnvironment, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc} = require('firebase/firestore');
const {handlers} = require('./shared-care');
const projectId = 'demo-dosebuddy-care';
let app, db, api, environment;
const request = (uid, data = {}) => ({auth: uid ? {uid} : null, data});
const medication = {id: 'med1', name: 'Sample', dosage: '10 mg', times: ['8:00 AM']};
async function grant(owner, caregiver, permissions = ['routine','history','manage_doses'], extra = {}) {
  await db.collection('careInvitations').doc(`${owner}_${caregiver}`).set({
    ownerUid: owner, recipientUid: caregiver, status: 'accepted', permissions,
    accessExpiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + 86400000), ...extra,
  });
}
before(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Firestore emulator is required; never run against production.');
  app = admin.initializeApp({projectId});
  db = app.firestore();
  environment = await initializeTestEnvironment({projectId,
    firestore: {rules: fs.readFileSync('../firestore.rules','utf8')}});
  api = handlers({db, timestamp: () => admin.firestore.FieldValue.serverTimestamp(),
    verifiedCaller: async r => {
      if (!r.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
      return {uid:r.auth.uid};
    }});
});
after(async () => { await environment?.cleanup(); await app?.delete(); });

test('a caregiver manages two owners without switching accounts or leaking private fields', async () => {
  for (const owner of ['alice','bob']) {
    await api.publishCareProfile(request(owner, {expectedRevision:0,displayName:owner,
      medications:[{...medication,notes:'private symptom',photo:'private'}]}));
    await grant(owner,'carer');
    const profile = await api.getCareProfile(request('carer',{ownerUid:owner}));
    assert.equal(profile.ownerUid,owner);
    assert.equal(profile.manageDoses,true);
    assert.equal(profile.medications[0].notes,undefined);
    assert.equal(profile.medications[0].photo,undefined);
  }
});
test('outsiders, pending, declined, expired and revoked grants cannot read', async () => {
  await assert.rejects(api.getCareProfile(request(null,{ownerUid:'alice'})), {code:'unauthenticated'});
  await assert.rejects(api.getCareProfile(request('outsider',{ownerUid:'alice'})), {code:'permission-denied'});
  for (const status of ['pending','declined','revoked']) {
    await grant('alice','denied',undefined,{status});
    await assert.rejects(api.getCareProfile(request('denied',{ownerUid:'alice'})), {code:'permission-denied'});
  }
  await grant('alice','denied',undefined,{accessExpiresAt:admin.firestore.Timestamp.fromMillis(Date.now()-1)});
  await assert.rejects(api.getCareProfile(request('denied',{ownerUid:'alice'})), {code:'permission-denied'});
});
test('routine-only access hides history and prevents dose writes and audit reads', async () => {
  await grant('alice','viewer',['routine']);
  const profile = await api.getCareProfile(request('viewer',{ownerUid:'alice'}));
  assert.deepEqual(profile.histories,{});
  assert.equal(profile.manageDoses,false);
  await assert.rejects(api.recordSharedDose(request('viewer',{
    ownerUid:'alice',medicationId:'med1',requestId:'forbidden',expectedRevision:0,
    date:'2026-01-01',scheduledTime:'8:00 AM',state:'taken'})),{code:'permission-denied'});
  await assert.rejects(api.getSharedDoseAudit(request('viewer',{ownerUid:'alice',medicationId:'med1'})),{code:'permission-denied'});
});
test('concurrent edits conflict, retries are idempotent and correction audit survives', async () => {
  const data = {ownerUid:'alice',medicationId:'med1',requestId:'initial',expectedRevision:0,
    date:'2026-01-01',scheduledTime:'8:00 AM',state:'taken'};
  await api.recordSharedDose(request('carer',data));
  assert.equal((await api.recordSharedDose(request('carer',data))).duplicate,true);
  await assert.rejects(api.recordSharedDose(request('carer',{...data,state:'missed'})),{code:'already-exists'});
  await assert.rejects(api.recordSharedDose(request('carer',{...data,requestId:'conflict',state:'missed'})),{code:'aborted'});
  await api.recordSharedDose(request('carer',{...data,requestId:'correction',expectedRevision:1,state:'unknown',reason:'Corrected mistaken tap'}));
  const profile = await api.getCareProfile(request('alice',{ownerUid:'alice'}));
  assert.equal(profile.histories.med1.records[0].state,'unknown');
  assert.equal(profile.histories.med1.records[0].actualTime,null);
  const audit = await api.getSharedDoseAudit(request('carer',{ownerUid:'alice',medicationId:'med1'}));
  assert.equal(audit.events.length,2);
  assert.equal(audit.events.find(e => e.entry.state === 'unknown').previous.state,'taken');
});
test('republishing routines preserves records and stale profile updates are rejected', async () => {
  await api.publishCareProfile(request('alice',{expectedRevision:1,displayName:'Alice',medications:[medication]}));
  await assert.rejects(api.publishCareProfile(request('alice',{expectedRevision:1,medications:[]})),{code:'aborted'});
  const profile = await api.getCareProfile(request('carer',{ownerUid:'alice'}));
  assert.equal(profile.histories.med1.revision,2);
});
test('revocation immediately blocks future operations; stopping and restarting does not resurrect grants', async () => {
  await api.stopCareSharing(request('bob'));
  await assert.rejects(api.getCareProfile(request('carer',{ownerUid:'bob'})),{code:'permission-denied'});
  await api.publishCareProfile(request('bob',{expectedRevision:1,medications:[medication]}));
  await assert.rejects(api.getCareProfile(request('carer',{ownerUid:'bob'})),{code:'permission-denied'});
});
test('an owner can restart after stopping sharing before the first publication', async () => {
  await api.stopCareSharing(request('newowner'));
  const stopped = await api.getCareProfile(request('newowner',{ownerUid:'newowner'}));
  assert.equal(stopped.sharingEnabled,false);
  assert.equal(stopped.revision,0);
  assert.deepEqual(stopped.medications,[]);
  await api.publishCareProfile(request('newowner',{expectedRevision:0,medications:[medication]}));
  assert.equal((await api.getCareProfile(request('newowner',{ownerUid:'newowner'}))).sharingEnabled,true);
});
test('client SDK cannot directly read, modify or delete shared records or forge invitations', async () => {
  for (const uid of ['alice','carer','outsider']) {
    const firestore = environment.authenticatedContext(uid).firestore();
    await assertFails(getDoc(doc(firestore,'careProfiles/alice')));
    await assertFails(getDoc(doc(firestore,'careProfiles/alice/history/med1')));
    await assertFails(setDoc(doc(firestore,'careProfiles/alice/history/med1'),{records:[]}));
    await assertFails(setDoc(doc(firestore,'careInvitations/alice_outsider'),{status:'accepted'}));
  }
});
