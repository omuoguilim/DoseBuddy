const {test} = require('node:test');
const assert = require('node:assert/strict');
const {routine, canAccess, doseChange} = require('./care-domain');
const now = new Date('2026-11-02T12:00:00Z');
const grant = overrides => ({ownerUid: 'owner', recipientUid: 'caregiver', status: 'accepted',
  permissions: ['routine', 'history', 'manage_doses'], accessExpiresAt: {toMillis: () => now.getTime() + 1000}, ...overrides});
test('only accepted unexpired matching grants authorize a caregiver', () => {
  assert.equal(canAccess(grant(), 'owner', 'caregiver', 'routine', +now), true);
  for (const overrides of [{status: 'pending'}, {status: 'revoked'}, {status: 'declined'},
    {recipientUid: 'stranger'}, {ownerUid: 'different'}, {permissions: ['routine']},
    {accessExpiresAt: {toMillis: () => +now - 1}}, {accessExpiresAt: null}]) {
    assert.equal(canAccess(grant(overrides), 'owner', 'caregiver', 'manage_doses', +now), false);
  }
});
test('owner can access own profile without a grant', () => {
  assert.equal(canAccess(null, 'owner', 'owner', 'manage_doses', +now), true);
});
test('publishing strips sensitive fields and validates IDs and schedules', () => {
  const medication = routine({id: 'med-1', name: 'Test', dosage: '10 mg', times: ['8:00 AM'],
    notes: 'private', sideEffects: ['private'], photo: '/private', takenLog: [{state: 'taken'}]});
  assert.deepEqual(Object.keys(medication).sort(), ['archived', 'dosage', 'id', 'name', 'times']);
  assert.throws(() => routine({...medication, id: '../bad'}));
  assert.throws(() => routine({...medication, times: ['29:00 AM']}));
  assert.throws(() => routine({...medication, times: Array(25).fill('8:00 AM')}));
});
test('correction replaces current record and preserves previous value as audit event', () => {
  const input = {date: '2026-11-01', scheduledTime: '8:00 AM', state: 'taken'};
  const first = doseChange({records: [], revision: 0}, input, 'owner', now);
  const corrected = doseChange(first, {...input, state: 'unknown', reason: 'Entered in error'}, 'caregiver', now);
  assert.equal(corrected.records.length, 1);
  assert.equal(corrected.records[0].state, 'unknown');
  assert.equal(corrected.event.previous.state, 'taken');
  assert.equal(corrected.event.actorUid, 'caregiver');
  assert.equal(corrected.revision, 2);
  assert.equal(first.records[0].state, 'taken');
});
test('taken, missed, skipped and unknown remain distinct', () => {
  for (const state of ['taken', 'missed', 'skipped', 'unknown']) {
    const result = doseChange({}, {date: '2026-11-01', scheduledTime: '8:00 AM', state}, 'owner', now);
    assert.equal(result.records[0].state, state);
  }
});
test('rejects invalid dates, states and future actual timestamps', () => {
  const input = {date: '2026-11-01', scheduledTime: '8:00 AM', state: 'taken'};
  for (const patch of [{date: '2026-02-30'}, {date: '2027-01-01'}, {state: 'guessed'},
    {actualTime: '2027-01-01T00:00:00Z'}, {actualTime: 'nonsense'}, {reason: 'x'.repeat(501)}]) {
    assert.throws(() => doseChange({}, {...input, ...patch}, 'owner', now));
  }
});
