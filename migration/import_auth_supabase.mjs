import crypto from 'node:crypto';
import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { outputDir, pick, readJson, requireEnv, writeJson } from './common.mjs';

if (String(process.env.DRY_RUN || 'true').toLowerCase() !== 'false') {
  throw new Error('Refusing to import Auth users while DRY_RUN is not explicitly false.');
}
const url = requireEnv('SUPABASE_URL');
const serviceKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY');
const client = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
const authExport = await readJson(path.join(outputDir(), 'firebase-auth-users.json'));
const firestore = await readJson(path.join(outputDir(), 'firestore-export.json'));
const idMapPath = path.resolve(process.env.AUTH_ID_MAP_PATH || './private/auth-id-map.json');
const sendActivation = String(process.env.SEND_ACTIVATION_EMAILS || 'false').toLowerCase() === 'true';
const redirectTo = process.env.AUTH_REDIRECT_URL?.trim();
if (sendActivation && !redirectTo) throw new Error('AUTH_REDIRECT_URL is required when SEND_ACTIVATION_EMAILS=true.');

const existingByEmail = new Map();
for (let page = 1; ; page += 1) {
  const { data, error } = await client.auth.admin.listUsers({ page, perPage: 1000 });
  if (error) throw error;
  for (const user of data.users) if (user.email) existingByEmail.set(user.email.toLowerCase(), user);
  if (data.users.length < 1000) break;
}

const idMap = {};
const report = {
  started_at: new Date().toISOString(), firebase_auth_users: 0, created: 0,
  reused: 0, legacy_aliases: 0, activation_emails_requested: 0,
  synthetic_email_accounts: 0, failures: [],
};
const profiles = Array.isArray(firestore.users) ? firestore.users : [];
const profileBySourceId = new Map();
const profileByEmail = new Map();
for (const profile of profiles) {
  const ids = [profile.__firebase_id, profile.uid, profile.id].filter(Boolean).map(String);
  for (const id of ids) profileBySourceId.set(id, profile);
  if (profile.email) profileByEmail.set(String(profile.email).trim().toLowerCase(), profile);
}

async function ensureUser(email, firebaseUid, metadata = {}, confirmed = true) {
  const normalizedEmail = email.trim().toLowerCase();
  let user = existingByEmail.get(normalizedEmail);
  if (!user) {
    const password = crypto.randomBytes(48).toString('base64url');
    const { data, error } = await client.auth.admin.createUser({
      email: normalizedEmail, password, email_confirm: confirmed,
      user_metadata: { ...metadata, firebase_uid: firebaseUid },
      app_metadata: { migrated_from: 'firebase' },
    });
    if (error || !data.user) throw error || new Error('Supabase Auth returned no user.');
    user = data.user;
    existingByEmail.set(normalizedEmail, user);
    report.created += 1;
  } else {
    report.reused += 1;
  }
  if (normalizedEmail.endsWith('@sakayta.app')) report.synthetic_email_accounts += 1;
  return user;
}

for (const firebaseUser of authExport.users || []) {
  report.firebase_auth_users += 1;
  try {
    const firebaseUid = String(firebaseUser.localId);
    const profile = profileBySourceId.get(firebaseUid) ||
      (firebaseUser.email ? profileByEmail.get(firebaseUser.email.toLowerCase()) : null);
    const email = firebaseUser.email || profile?.email;
    if (!email) throw new Error('Auth record has no email.');
    const user = await ensureUser(email, firebaseUid, {
      full_name: firebaseUser.displayName || pick(profile, 'fullName', 'full_name', 'name') || '',
      firebase_uid: firebaseUid,
    }, Boolean(firebaseUser.emailVerified));
    idMap[firebaseUid] = user.id;
    if (profile) {
      for (const alias of [profile.__firebase_id, profile.uid, profile.id].filter(Boolean).map(String)) {
        if (!idMap[alias]) report.legacy_aliases += 1;
        idMap[alias] = user.id;
      }
    }
    if (sendActivation && !email.toLowerCase().endsWith('@sakayta.app')) {
      const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo });
      if (error) throw error;
      report.activation_emails_requested += 1;
    }
  } catch (error) {
    report.failures.push({ firebase_uid: firebaseUser.localId, reason: error.message });
  }
}

for (const profile of profiles) {
  const aliases = [profile.__firebase_id, profile.uid, profile.id].filter(Boolean).map(String);
  if (aliases.some((id) => idMap[id])) continue;
  try {
    let email = String(profile.email || '').trim().toLowerCase();
    if (!email) {
      const digits = String(profile.mobile || profile.phoneNumber || '').replace(/\D/g, '');
      if (!digits) throw new Error('Legacy profile has neither email nor mobile identity.');
      const normalized = digits.startsWith('0') && digits.length === 11 ? `63${digits.slice(1)}` : digits;
      email = `${normalized}@sakayta.app`;
    }
    const canonical = aliases[0];
    const user = await ensureUser(email, canonical, {
      full_name: pick(profile, 'fullName', 'full_name', 'name') || '', firebase_uid: canonical,
    }, Boolean(profile.email_verified));
    for (const alias of aliases) {
      idMap[alias] = user.id;
      report.legacy_aliases += 1;
    }
    if (sendActivation && !email.endsWith('@sakayta.app')) {
      const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo });
      if (error) throw error;
      report.activation_emails_requested += 1;
    }
  } catch (error) {
    report.failures.push({ firebase_uid: aliases[0] || 'unknown', reason: error.message });
  }
}

report.completed_at = new Date().toISOString();
await writeJson(idMapPath, idMap);
await writeJson(path.join(outputDir(), 'auth-import-report.json'), report);
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
if (report.failures.length) process.exitCode = 2;
