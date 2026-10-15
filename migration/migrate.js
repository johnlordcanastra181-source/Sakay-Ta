
require('dotenv').config();
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');
const { v5: uuidv5 } = require('uuid');

// We use a deterministic namespace for generating UUIDs from Firebase UIDs
const SAKAY_TA_NAMESPACE = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

function getUuid(firebaseUid) {
  return uuidv5(firebaseUid, SAKAY_TA_NAMESPACE);
}

async function run() {
  if (!process.env.FIREBASE_SERVICE_ACCOUNT_PATH) {
    console.error('Missing FIREBASE_SERVICE_ACCOUNT_PATH in .env');
    process.exit(1);
  }
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Missing Supabase credentials in .env');
    process.exit(1);
  }

  const serviceAccount = require(process.env.FIREBASE_SERVICE_ACCOUNT_PATH);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });

  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false }
  });

  const db = admin.firestore();
  
  console.log('Starting Migration...');

  // 1. Migrate Users to Supabase Auth & Profiles
  const usersSnapshot = await db.collection('users').get();
  console.log(Found  users.);

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const newId = getUuid(doc.id);
    
    // We create the user in Supabase Auth via admin API
    try {
      await supabase.auth.admin.createUser({
        id: newId,
        email: data.email || ${doc.id}@sakayta.migration.local,
        email_confirm: true,
        user_metadata: { firebase_uid: doc.id }
      });
    } catch(e) {
      if (!e.message.includes('already exists')) {
        console.error(Failed to create Auth user : );
      }
    }

    // Insert into public.profiles
    const { error: profileError } = await supabase.from('profiles').upsert({
      id: newId,
      firebase_uid: doc.id,
      full_name: data.full_name || data.fullName || 'Unknown',
      email: data.email,
      phone_number: data.mobile || data.phoneNumber,
      role: data.role || 'passenger',
      status: data.status || 'active',
      profile_photo_url: data.profile_photo_url || data.profilePhotoUrl,
      avatar_color: data.avatar_color || data.avatarColor || 0,
      is_online: data.is_online || data.isOnline || false,
      is_available: data.is_available || data.isAvailable || true,
      latitude: data.latitude,
      longitude: data.longitude,
      created_at: data.createdAt ? data.createdAt.toDate().toISOString() : new Date().toISOString()
    });
    
    if (profileError) console.error(Profile error for :, profileError);
  }
  
  console.log('Migration completed.');
}

run().catch(console.error);

