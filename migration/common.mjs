import 'dotenv/config';
import fs from 'node:fs/promises';
import path from 'node:path';

export const collections = [
  'users', 'admins', 'drivers', 'passengers', 'rides', 'bookings',
  'chat_messages', 'toda', 'transactions', 'ratings', 'payments',
  'driver_earnings', 'withdrawals', 'toda_associations', 'fare_matrix',
  'magic_links', 'email_otps', 'notifications', 'reports',
];

export function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export function outputDir() {
  return path.resolve(process.env.EXPORT_DIR || './output');
}

export async function readJson(file) {
  return JSON.parse(await fs.readFile(file, 'utf8'));
}

export async function writeJson(file, value) {
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

export function normalize(value) {
  if (value === undefined) return null;
  if (value === null || typeof value !== 'object') return value;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (typeof value.latitude === 'number' && typeof value.longitude === 'number') {
    return { latitude: value.latitude, longitude: value.longitude };
  }
  if (Buffer.isBuffer(value)) return { base64: value.toString('base64') };
  if (Array.isArray(value)) return value.map(normalize);
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, normalize(item)]));
}

export const pick = (source, ...keys) => {
  for (const key of keys) {
    if (source?.[key] !== undefined && source[key] !== null) return source[key];
  }
  return null;
};

export function bool(value, fallback = false) {
  if (value === null || value === undefined) return fallback;
  return value === true || value === 1 || value === '1' || value === 'true';
}

export function iso(value) {
  if (!value) return null;
  if (typeof value === 'number') {
    const millis = value < 10_000_000_000 ? value * 1000 : value;
    return new Date(millis).toISOString();
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
}

export function vehicle(value) {
  const normalized = String(value || 'tricycle').toLowerCase();
  return normalized.includes('habal') || normalized.includes('motor') ? 'habal' : 'tricycle';
}

export function rideStatus(value) {
  const normalized = String(value || 'searching').toLowerCase();
  return ({
    pending: 'searching', requested: 'searching', waiting: 'searching',
    assigned: 'accepted', confirmed: 'accepted', on_the_way: 'accepted',
    arriving: 'accepted', ongoing: 'started', in_progress: 'started',
    canceled: 'cancelled', rejected: 'cancelled',
  })[normalized] || normalized;
}

export function asArray(exported, collection) {
  return Array.isArray(exported?.[collection]) ? exported[collection] : [];
}

export function authId(idMap, firebaseUid, context) {
  if (!firebaseUid) return null;
  const id = idMap[firebaseUid];
  if (!id) throw new Error(`No Auth ID mapping for ${context}: ${firebaseUid}`);
  return id;
}

export async function upsertBatches(client, table, rows, onConflict, batchSize = 250) {
  for (let start = 0; start < rows.length; start += batchSize) {
    const batch = rows.slice(start, start + batchSize);
    if (!batch.length) continue;
    const { error } = await client.from(table).upsert(batch, { onConflict });
    if (error) throw new Error(`${table} batch ${start}: ${error.message}`);
  }
  return rows.length;
}
