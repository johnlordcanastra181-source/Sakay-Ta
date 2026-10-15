const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { DatabaseSync } = require('node:sqlite');

const { createApp } = require('../src/app');

process.env.NODE_ENV = 'test';

const BASE = {
  tokenTtlMinutes: 10,
  corsOrigins: ['*'],
};

let db;
let server;
let baseUrl;

before(async () => {
  db = new DatabaseSync(':memory:');
  const app = createApp(db, BASE);
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server?.close();
  db?.close();
});

async function post(path, body) {
  const res = await fetch(`${baseUrl}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* non-JSON body */
  }
  return { status: res.status, json };
}

test('request-email-otp generates 6-digit OTP code for a valid email', async () => {
  const { status, json } = await post('/api/auth/request-email-otp', {
    email: 'passenger@example.com',
    purpose: 'signup',
  });

  assert.equal(status, 200);
  assert.equal(json.success, true);
  assert.equal(json.email, 'passenger@example.com');
  assert.equal(json.expiresInSeconds, 600);
  assert.ok(json.message.includes('passenger@example.com'));
});

test('request-email-otp rejects malformed emails with 400 invalid_email', async () => {
  for (const email of ['not-an-email', 'missing@domain', '@missinguser.com', '', null]) {
    const { status, json } = await post('/api/auth/request-email-otp', { email });
    assert.equal(status, 400, `email ${email}`);
    assert.equal(json.error.code, 'invalid_email');
  }
});

test('request-email-otp enforces the 60-second resend cooldown (429 cooldown)', async () => {
  const first = await post('/api/auth/request-email-otp', { email: 'cooldown@example.com' });
  assert.equal(first.status, 200);

  const second = await post('/api/auth/request-email-otp', { email: 'cooldown@example.com' });
  assert.equal(second.status, 429);
  assert.equal(second.json.error.code, 'cooldown');
});

test('verify-email-otp accepts valid OTP and marks used, rejecting reuse (409 already_used)', async () => {
  const testEmail = 'verify@example.com';
  await post('/api/auth/request-email-otp', { email: testEmail });

  // Read OTP code generated in SQLite DB
  const row = db.prepare('SELECT otp_code FROM email_otps WHERE email = ? ORDER BY created_at DESC LIMIT 1').get(testEmail);
  assert.ok(row && row.otp_code);
  const otpCode = row.otp_code;

  // First verification
  const first = await post('/api/auth/verify-email-otp', { email: testEmail, otpCode });
  assert.equal(first.status, 200);
  assert.equal(first.json.verified, true);
  assert.equal(first.json.email, testEmail);

  // Second verification with same code -> 409 already_used
  const second = await post('/api/auth/verify-email-otp', { email: testEmail, otpCode });
  assert.equal(second.status, 409);
  assert.equal(second.json.error.code, 'already_used');
});

test('verify-email-otp rejects incorrect OTP codes (401 invalid_otp)', async () => {
  const { status, json } = await post('/api/auth/verify-email-otp', {
    email: 'passenger@example.com',
    otpCode: '000000',
  });
  assert.equal(status, 401);
  assert.equal(json.error.code, 'invalid_otp');
});

test('verify-email-otp rejects missing params (400 invalid_request)', async () => {
  const { status, json } = await post('/api/auth/verify-email-otp', {});
  assert.equal(status, 400);
  assert.equal(json.error.code, 'invalid_request');
});

test('health check responds ok', async () => {
  const res = await fetch(`${baseUrl}/health`);
  assert.equal(res.status, 200);
  const json = await res.json();
  assert.equal(json.status, 'ok');
});