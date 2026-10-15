import { createRequire } from 'node:module';
import fs from 'node:fs/promises';
import path from 'node:path';
import { outputDir, writeJson } from './common.mjs';

const firebaseToolsLib = process.env.FIREBASE_TOOLS_LIB ||
  'C:/Users/jlcap/AppData/Roaming/npm/node_modules/firebase-tools/lib';
const require = createRequire(import.meta.url);
const auth = require(path.join(firebaseToolsLib, 'auth.js'));
const account = auth.getGlobalDefaultAccount();
if (!account?.tokens?.refresh_token) throw new Error('No Firebase CLI session.');
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

let bucket = process.env.FIREBASE_STORAGE_BUCKET || 'sakay-ta.firebasestorage.app';
let base = `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(bucket)}/o`;
const objects = [];
let pageToken = '';
let noBucket = false;
do {
  const url = new URL(base);
  url.searchParams.set('maxResults', '1000');
  if (pageToken) url.searchParams.set('pageToken', pageToken);
  const response = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!response.ok && response.status === 404 && objects.length === 0) {
    const bucketsResponse = await fetch(
      'https://storage.googleapis.com/storage/v1/b?project=sakay-ta',
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    if (!bucketsResponse.ok) throw new Error(`Storage bucket discovery failed (${bucketsResponse.status}).`);
    const buckets = await bucketsResponse.json();
    const discovered = (buckets.items || []).find((item) => item.name.startsWith('sakay-ta'));
    if (!discovered) {
      noBucket = true;
      break;
    }
    bucket = discovered.name;
    base = `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(bucket)}/o`;
    continue;
  }
  if (!response.ok) throw new Error(`Storage list failed (${response.status}): ${(await response.text()).slice(0, 500)}`);
  const page = await response.json();
  objects.push(...(page.items || []));
  pageToken = page.nextPageToken || '';
} while (pageToken);

if (noBucket) {
  await writeJson(path.join(outputDir(), 'firebase-storage-manifest.json'), {
    bucket, exported_at: new Date().toISOString(), files: [], failed: [], note: 'No Firebase Storage bucket exists for this project.',
  });
  process.stdout.write('Storage files: 0; no project bucket exists.\n');
} else {
  const backupRoot = path.join(outputDir(), 'firebase-storage');
  const manifest = { bucket, exported_at: new Date().toISOString(), files: [], failed: [] };
  for (const object of objects) {
    try {
      const download = new URL(`${base}/${encodeURIComponent(object.name)}`);
      download.searchParams.set('alt', 'media');
      const response = await fetch(download, { headers: { Authorization: `Bearer ${accessToken}` } });
      if (!response.ok) throw new Error(`download failed (${response.status})`);
      const bytes = Buffer.from(await response.arrayBuffer());
      const destination = path.join(backupRoot, ...object.name.split('/'));
      await fs.mkdir(path.dirname(destination), { recursive: true });
      await fs.writeFile(destination, bytes, { mode: 0o600 });
      manifest.files.push({
        name: object.name,
        content_type: object.contentType || 'application/octet-stream',
        size: Number(object.size || bytes.length),
        md5_hash: object.md5Hash || null,
        created_at: object.timeCreated || null,
      });
      process.stdout.write(`exported: ${object.name}\n`);
    } catch (error) {
      manifest.failed.push({ name: object.name, reason: error.message });
    }
  }
  await writeJson(path.join(outputDir(), 'firebase-storage-manifest.json'), manifest);
  process.stdout.write(`Storage files: ${manifest.files.length}; failed: ${manifest.failed.length}\n`);
  if (manifest.failed.length) process.exitCode = 2;
}
