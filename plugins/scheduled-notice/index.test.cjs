'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { buildJob } = require('./index.cjs');

const NOW = Date.parse('2026-11-10T12:00:00.000Z');

test('disabled plugin has no scheduled job', () => {
  assert.equal(buildJob({ enabled: false }), null);
});

test('accepts one future notice with an explicit timezone', () => {
  const job = buildJob({
    enabled: true,
    sessionId: 'sender-session',
    chatId: '6281234567890@c.us',
    sendAt: '2026-11-11T09:00:00+07:00',
    message: 'Pengingat: janji temu kita besok pukul 09.00.'
  }, NOW);

  assert.equal(job.sessionId, 'sender-session');
  assert.equal(job.chatId, '6281234567890@c.us');
  assert.equal(job.sendAt, '2026-11-11T02:00:00.000Z');
  assert.ok(job.fingerprint.includes('Pengingat: janji temu kita besok pukul 09.00.'));
});

test('requires an explicit timezone offset', () => {
  assert.throws(() => buildJob({
    enabled: true,
    sessionId: 'sender-session',
    chatId: '6281234567890@c.us',
    sendAt: '2026-11-11T09:00:00',
    message: 'Pengingat otomatis'
  }, NOW), /include a timezone/);
});

test('rejects an empty message', () => {
  assert.throws(() => buildJob({
    enabled: true,
    sessionId: 'sender-session',
    chatId: '6281234567890@c.us',
    sendAt: '2026-11-11T09:00:00+07:00',
    message: '   '
  }, NOW), /cannot be empty/);
});

test('rejects schedules outside the 30-day horizon', () => {
  assert.throws(() => buildJob({
    enabled: true,
    sessionId: 'sender-session',
    chatId: '6281234567890@c.us',
    sendAt: '2027-01-01T09:00:00+07:00',
    message: 'Pengingat otomatis'
  }, NOW), /30 days/);
});
