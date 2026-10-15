import fs from 'node:fs/promises';
import path from 'node:path';
import admin from 'firebase-admin';
import { collections, normalize, outputDir, requireEnv, writeJson } from './common.mjs';

const projectId = process.env.FIREBASE_PROJECT_ID || 'sakay-ta';
const serviceAccountPath = requireEnv('FIREBASE_SERVICE_ACCOUNT_PATH');
const serviceAccount = JSON.parse(await fs.readFile(serviceAccountPath, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount), projectId });
const db = admin.firestore();
const exported = {};
const counts = {};

for (const name of collections) {
  const snapshot = await db.collection(name).get();
  exported[name] = snapshot.docs.map((document) => ({
    __firebase_id: document.id,
    ...normalize(document.data()),
  }));
  counts[name] = exported[name].length;
  process.stdout.write(`${name}: ${counts[name]}\n`);
}

const directory = outputDir();
await fs.mkdir(directory, { recursive: true });
await writeJson(path.join(directory, 'firestore-export.json'), exported);
await writeJson(path.join(directory, 'firebase-counts.json'), counts);
await admin.app().delete();
process.stdout.write(`Export saved to ${directory}\n`);
