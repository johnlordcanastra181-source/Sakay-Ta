import { createRequire } from 'node:module';
import path from 'node:path';
import { collections, outputDir, writeJson } from './common.mjs';

// Uses the existing Firebase CLI login in memory. OAuth tokens are never
// written to migration output or printed. This is a fallback for operators
// who have Firebase CLI access but do not have a service-account JSON file.
const firebaseToolsLib = process.env.FIREBASE_TOOLS_LIB ||
  'C:/Users/jlcap/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const require = createRequire(import.meta.url);
const auth = require(path.join(firebaseToolsLib, 'auth.js'));
const account = auth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) {
  throw new Error('No Firebase CLI session. Run firebase login first.');
}
const cachedTokenIsUsable = typeof account.tokens.access_token === 'string' &&
  Number(account.tokens.expires_at || 0) > Date.now() + 60_000;
const tokenResult = cachedTokenIsUsable ? account.tokens : await auth.getAccessToken(
  account.tokens.refresh_token,
  Array.isArray(account.tokens.scopes) && account.tokens.scopes.length
    ? account.tokens.scopes
    : ['https://www.googleapis.com/auth/cloud-platform'],
);
const accessToken = tokenResult?.access_token;
if (!accessToken) throw new Error('Firebase CLI did not return an access token.');

const projectId = process.env.FIREBASE_PROJECT_ID || 'sakay-ta';
const databaseId = process.env.FIRESTORE_DATABASE_ID || '(default)';
const root = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
  `/databases/${encodeURIComponent(databaseId)}/documents`;
const exported = {};
const counts = {};

for (const collection of collections) {
  const rows = [];
  let pageToken = '';
  do {
    const url = new URL(`${root}/${encodeURIComponent(collection)}`);
    url.searchParams.set('pageSize', '300');
    url.searchParams.set('showMissing', 'false');
    if (pageToken) url.searchParams.set('pageToken', pageToken);
    const response = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
    if (!response.ok) {
      const body = await response.text();
      throw new Error(`${collection}: Firestore REST ${response.status}: ${body.slice(0, 500)}`);
    }
    const page = await response.json();
    for (const document of page.documents || []) {
      rows.push({
        __firebase_id: decodeURIComponent(document.name.split('/').at(-1)),
        ...decodeFields(document.fields || {}),
        __firebase_create_time: document.createTime || null,
        __firebase_update_time: document.updateTime || null,
      });
    }
    pageToken = page.nextPageToken || '';
  } while (pageToken);
  exported[collection] = rows;
  counts[collection] = rows.length;
  process.stdout.write(`${collection}: ${rows.length}\n`);
}

const directory = outputDir();
await writeJson(path.join(directory, 'firestore-export.json'), exported);
await writeJson(path.join(directory, 'firebase-counts.json'), counts);
process.stdout.write(`Firestore export saved to ${directory}\n`);

function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

function decodeValue(value) {
  if ('nullValue' in value) return null;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('stringValue' in value) return value.stringValue;
  if ('bytesValue' in value) return { base64: value.bytesValue };
  if ('referenceValue' in value) return value.referenceValue;
  if ('geoPointValue' in value) return value.geoPointValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in value) return decodeFields(value.mapValue.fields || {});
  return null;
}
