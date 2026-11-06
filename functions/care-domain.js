'use strict';

// Shared records deliberately exclude photos, symptoms, free-text medication
// notes, contact details and local device settings.
class CareError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
const fail = (message) => { throw new CareError('invalid-argument', message); };
function text(value, max, label) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(`Invalid ${label}.`);
  return value.trim();
}
function identifier(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) fail('Invalid identifier.');
  return value;
}
function routine(input) {
  if (!input || typeof input !== 'object') fail('Invalid medication.');
  const id = identifier(input.id);
  if (!Array.isArray(input.times) || input.times.length > 24 || input.times.some(t =>
    typeof t !== 'string' || !/^(?:[1-9]|1[0-2]):[0-5][0-9] (?:AM|PM)$/.test(t))) fail('Invalid schedule times.');
  return {id, name: text(input.name, 160, 'name'), dosage: text(input.dosage, 100, 'dosage'),
    times: [...new Set(input.times)], archived: input.archived === true};
}
function canAccess(invitation, ownerUid, actorUid, permission, now = Date.now()) {
  if (ownerUid === actorUid) return true;
  return Boolean(invitation && invitation.ownerUid === ownerUid &&
    invitation.recipientUid === actorUid && invitation.status === 'accepted' &&
    invitation.accessExpiresAt?.toMillis() > now &&
    invitation.permissions?.includes(permission));
}
function doseChange(current, input, actorUid, now = new Date()) {
  const date = text(input.date, 10, 'date');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(date)) ||
      new Date(date).toISOString().slice(0, 10) !== date) fail('Invalid date.');
  // Scheduled dates may be today in any timezone, but not a future calendar day.
  if (date > new Date(now.getTime() + 14 * 3600000).toISOString().slice(0, 10)) fail('Future dose date.');
  const scheduledTime = text(input.scheduledTime, 16, 'scheduled time');
  if (!/^(?:[1-9]|1[0-2]):[0-5][0-9] (?:AM|PM)$/.test(scheduledTime)) fail('Invalid scheduled time.');
  if (!['taken', 'missed', 'skipped', 'unknown'].includes(input.state)) fail('Invalid dose state.');
  const reason = input.reason == null ? '' : String(input.reason).trim();
  if (reason.length > 500) fail('Reason is too long.');
  let actualTime = null;
  if (input.state === 'taken' && input.actualTime != null) {
    actualTime = input.actualTime;
    if (typeof actualTime !== 'string' || !Number.isFinite(Date.parse(actualTime)) ||
        Date.parse(actualTime) > now.getTime()) fail('Invalid actual time.');
    actualTime = new Date(actualTime).toISOString();
  }
  const records = Array.isArray(current.records) ? current.records : [];
  const key = `${date}|${scheduledTime}`;
  const previous = records.find(r => `${r.date}|${r.scheduledTime}` === key) || null;
  const entry = {date, scheduledTime, state: input.state, reason, actualTime,
    recordedAt: now.toISOString(), actorUid};
  const next = records.filter(r => `${r.date}|${r.scheduledTime}` !== key);
  next.push(entry);
  if (next.length > 500) fail('Shared history limit reached. Export or start a new profile period.');
  return {records: next, revision: (current.revision || 0) + 1,
    event: {previous, entry, actorUid, recordedAt: now.toISOString()}};
}
module.exports = {CareError, identifier, routine, canAccess, doseChange};
