const test = require('node:test');
const assert = require('node:assert/strict');
const { EmailService } = require('../src/emailService');

test('Unconfigured email delivery returns failure and never exposes a development OTP', async () => {
  const logs = [];
  const service = new EmailService({}, {
    info: (message) => logs.push(message),
    error: (message) => logs.push(message),
  });
  service.pass = '';
  const result = await service.sendOtpEmail({email: 'passenger@example.com', otpCode: '894312'});
  assert.equal(result.sent, false);
  assert.equal(result.fallback, false);
  assert.equal(result.devOtpCode, undefined);
  assert.equal(result.otpCode, undefined);
  assert.ok(logs.every((line) => !line.includes('894312')));
});
