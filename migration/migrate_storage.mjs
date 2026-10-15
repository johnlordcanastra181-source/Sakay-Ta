import fs from 'node:fs/promises';
import path from 'node:path';
import admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';
import { outputDir, readJson, requireEnv, writeJson } from './common.mjs';

if (String(process.env.DRY_RUN || 'true').toLowerCase() !== 'false') {
  throw new Error('Refusing to migrate files while DRY_RUN is not explicitly set to false.');
}
const serviceAccount = JSON.parse(await fs.readFile(requireEnv('FIREBASE_SERVICE_ACCOUNT_PATH'), 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: process.env.FIREBASE_PROJECT_ID || 'sakay-ta',
  storageBucket: requireEnv('FIREBASE_STORAGE_BUCKET'),
});
const bucket = admin.storage().bucket();
const supabase = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false, autoRefreshToken: false },
});
const idMap = await readJson(requireEnv('AUTH_ID_MAP_PATH'));
const report = { started_at: new Date().toISOString(), discovered: 0, uploaded: 0, skipped: [], failed: [] };

function profileOwner(fileName) {
  return Object.keys(idMap).sort((a, b) => b.length - a.length)
    .find((firebaseUid) => fileName === firebaseUid || fileName.startsWith(`${firebaseUid}_`));
}

function documentType(fileName, folder) {
  const normalized = `${folder}/${fileName}`.toLowerCase();
  if (normalized.includes('license_front') || normalized.includes('/license/')) return 'license_front';
  if (normalized.includes('license_back')) return 'license_back';
  if (normalized.includes('license_selfie')) return 'license_selfie';
  if (normalized.includes('orcr') || normalized.includes('or_cr')) return 'or_cr';
  if (normalized.includes('vehicle_front')) return 'vehicle_front';
  if (normalized.includes('vehicle_side')) return 'vehicle_side';
  if (normalized.includes('vehicle_back')) return 'vehicle_back';
  if (normalized.includes('barangay_clearance')) return 'barangay_clearance';
  if (normalized.includes('police_clearance')) return 'police_clearance';
  if (normalized.includes('mayors_permit')) return 'mayors_permit';
  if (normalized.includes('/profile/')) return 'profile';
  return null;
}

const [files] = await bucket.getFiles();
for (const file of files) {
  if (!file.name.startsWith('profile_photos/') && !file.name.startsWith('driver_documents/')) continue;
  report.discovered += 1;
  try {
    const parts = file.name.split('/');
    let firebaseUid;
    let targetBucket;
    let targetPath;
    let type = null;
    if (parts[0] === 'profile_photos') {
      firebaseUid = profileOwner(parts.at(-1));
      targetBucket = 'avatars';
      targetPath = firebaseUid ? `${idMap[firebaseUid]}/${parts.at(-1)}` : null;
    } else {
      firebaseUid = parts[1];
      targetBucket = 'driver-documents';
      targetPath = idMap[firebaseUid] ? `${idMap[firebaseUid]}/${parts.slice(2).join('/')}` : null;
      type = documentType(parts.at(-1), parts[2] || '');
    }
    if (!firebaseUid || !idMap[firebaseUid] || !targetPath) {
      report.skipped.push({ source: file.name, reason: 'no Firebase UID -> Supabase UUID mapping' });
      continue;
    }
    if (targetBucket === 'driver-documents' && !type) {
      report.skipped.push({ source: file.name, reason: 'unrecognized private document type' });
      continue;
    }
    const [metadata] = await file.getMetadata();
    const [bytes] = await file.download();
    const { error: uploadError } = await supabase.storage.from(targetBucket).upload(targetPath, bytes, {
      contentType: metadata.contentType || 'application/octet-stream', upsert: true,
    });
    if (uploadError) throw uploadError;

    if (targetBucket === 'avatars') {
      const { error } = await supabase.from('profiles').update({ profile_photo_path: targetPath }).eq('id', idMap[firebaseUid]);
      if (error) throw error;
    } else {
      const { error } = await supabase.from('driver_documents').upsert({
        driver_id: idMap[firebaseUid], document_type: type, storage_path: targetPath,
      }, { onConflict: 'driver_id,document_type,storage_path' });
      if (error) throw error;
    }
    report.uploaded += 1;
  } catch (error) {
    report.failed.push({ source: file.name, reason: error.message });
  }
}

report.completed_at = new Date().toISOString();
await writeJson(path.join(outputDir(), 'storage-report.json'), report);
await admin.app().delete();
process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
if (report.failed.length) process.exitCode = 2;
