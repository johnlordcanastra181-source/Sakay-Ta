import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
import {
  asArray, authId, bool, iso, outputDir, pick, readJson, requireEnv,
  rideStatus, upsertBatches, vehicle, writeJson,
} from './common.mjs';

if (String(process.env.DRY_RUN || 'true').toLowerCase() !== 'false') {
  throw new Error('Refusing to import while DRY_RUN is not explicitly set to false.');
}
const client = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false, autoRefreshToken: false },
});
const directory = outputDir();
const exported = await readJson(path.join(directory, 'firestore-export.json'));
const idMap = await readJson(requireEnv('AUTH_ID_MAP_PATH'));
const report = { started_at: new Date().toISOString(), tables: {}, skipped: [], errors: [] };

// Firestore profile documents can contain stale or duplicated email values. Supabase
// Auth is the canonical identity source after migration, so use its email for every
// profile row instead of allowing legacy profile data to violate email uniqueness.
const authEmailById = new Map();
for (let page = 1; ; page += 1) {
  const { data, error } = await client.auth.admin.listUsers({ page, perPage: 1000 });
  if (error) throw error;
  for (const user of data.users) {
    if (user.email) authEmailById.set(user.id, user.email.toLowerCase());
  }
  if (data.users.length < 1000) break;
}

function dedupe(rows, key, context) {
  const unique = new Map();
  for (const row of rows) {
    const id = row[key];
    if (unique.has(id)) {
      report.skipped.push({ context: `${context} ${id}`, reason: 'duplicate legacy identity merged' });
      const previous = unique.get(id);
      unique.set(id, Object.fromEntries(Object.entries({ ...previous, ...row }).map(([field, value]) => [
        field,
        value === null || value === '' ? previous[field] : value,
      ])));
    } else {
      unique.set(id, row);
    }
  }
  return [...unique.values()];
}

function mapped(firebaseUid, context, optional = false) {
  try { return authId(idMap, firebaseUid, context); }
  catch (error) {
    if (!optional) throw error;
    report.skipped.push({ context, firebase_uid: firebaseUid, reason: error.message });
    return null;
  }
}

const users = asArray(exported, 'users');
const profiles = dedupe(users.map((row) => {
  const id = mapped(pick(row, 'uid', 'id', '__firebase_id'), `profile ${row.__firebase_id}`);
  return {
    id,
    firebase_uid: pick(row, 'uid', 'id', '__firebase_id'),
    full_name: pick(row, 'fullName', 'full_name', 'name') || '',
    email: authEmailById.get(id) || pick(row, 'email')?.toLowerCase() || null,
    mobile: pick(row, 'mobile', 'phoneNumber', 'phone_number'),
    email_verified: bool(pick(row, 'emailVerified', 'email_verified')),
    account_status: pick(row, 'status', 'verificationStatus') || 'active',
    address: pick(row, 'address'),
    latitude: pick(row, 'latitude'),
    longitude: pick(row, 'longitude'),
    location_updated_at: iso(pick(row, 'locationUpdatedAt', 'location_updated_at')),
    profile_photo_path: pick(row, 'profilePhotoPath', 'profile_photo_path', 'profilePhotoUrl', 'profile_photo_url'),
    avatar_color: Number(pick(row, 'avatarColor', 'avatar_color') || 0),
    created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
  };
}), 'id', 'profile');

// A small number of legacy profile documents reuse the same mobile number for
// different Firebase identities. Keep the first canonical owner and clear only
// the conflicting duplicate so the unique contact constraint remains enforced.
const mobileOwner = new Map();
for (const profile of profiles) {
  if (!profile.mobile) continue;
  const normalizedMobile = String(profile.mobile).replace(/\s+/g, '');
  const owner = mobileOwner.get(normalizedMobile);
  if (owner && owner !== profile.id) {
    report.skipped.push({ context: `profile ${profile.id}`, reason: 'duplicate legacy mobile cleared' });
    profile.mobile = null;
  } else {
    profile.mobile = normalizedMobile;
    mobileOwner.set(normalizedMobile, profile.id);
  }
}
report.tables.profiles = await upsertBatches(client, 'profiles', profiles, 'id');

const identityMappings = Object.entries(idMap)
  .filter(([firebaseUid, userId]) => !firebaseUid.startsWith('_') && typeof userId === 'string')
  .map(([firebaseUid, userId]) => ({ firebase_uid: firebaseUid, user_id: userId }));
report.tables.firebase_user_map = await upsertBatches(client, 'firebase_user_map', identityMappings, 'firebase_uid');

const admins = dedupe(asArray(exported, 'admins').map((row) => ({
  user_id: mapped(pick(row, 'uid', 'id', '__firebase_id'), `admin ${row.__firebase_id}`),
  role: String(pick(row, 'role') || 'admin') === 'super_admin' ? 'super_admin' : 'admin',
  status: pick(row, 'status') || 'active',
  department: pick(row, 'department') || 'Operations',
  permissions: String(pick(row, 'permissions') || '').split(',').map((v) => v.trim()).filter(Boolean),
  created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
  updated_at: iso(pick(row, 'updatedAt', 'updated_at')) || new Date().toISOString(),
  last_login_at: iso(pick(row, 'lastLogin', 'last_login')),
})), 'user_id', 'admin');
report.tables.admin_roles = await upsertBatches(client, 'admin_roles', admins, 'user_id');

const todaRows = asArray(exported, 'toda').map((row) => ({
  id: String(pick(row, 'id', '__firebase_id')),
  name: pick(row, 'name') || '', code: pick(row, 'code') || row.__firebase_id,
  city: pick(row, 'city', 'municipality') || '', president: pick(row, 'president'),
  contact_number: pick(row, 'contactNumber', 'contact_number'),
  is_active: bool(pick(row, 'isActive', 'is_active'), true),
}));
report.tables.todas = await upsertBatches(client, 'todas', todaRows, 'id');
const todaIds = new Set(todaRows.map((row) => row.id));

const drivers = asArray(exported, 'drivers').map((row) => {
  const firebaseUid = pick(row, 'userId', 'user_id', 'uid', '__firebase_id');
  const personal = row.personalInfo || {};
  const license = row.licenseInfo || {};
  const vehicleInfo = row.vehicleInfo || {};
  const legacyTodaId = pick(row, 'todaId', 'toda_id') ?? row.todaAssociation?.id ?? null;
  const todaId = legacyTodaId !== null && todaIds.has(String(legacyTodaId))
    ? String(legacyTodaId)
    : null;
  if (legacyTodaId !== null && todaId === null) {
    report.skipped.push({ context: `driver ${row.__firebase_id}`, reason: 'missing legacy TODA reference cleared' });
  }
  return {
    user_id: mapped(firebaseUid, `driver ${row.__firebase_id}`), firebase_uid: firebaseUid,
    application_status: pick(row, 'applicationStatus', 'verificationStatus', 'verification_status', 'status') || 'pending',
    is_online: bool(pick(row, 'isOnline', 'is_online')), is_available: bool(pick(row, 'isAvailable', 'is_available')),
    vehicle_type: vehicle(pick(row, 'vehicleType', 'vehicle_type', vehicleInfo.type)),
    plate_number: pick(row, 'plateNumber', 'plate_number', vehicleInfo.plateNumber) || '',
    license_type: pick(row, 'licenseType', 'license_type', license.type),
    license_number: pick(row, 'licenseNumber', 'license_number', license.number),
    license_expiry: pick(row, 'licenseExpiry', 'license_expiry', license.expiry) || null,
    vehicle_make: pick(row, 'make', vehicleInfo.make), vehicle_model: pick(row, 'model', vehicleInfo.model),
    vehicle_year: Number(pick(row, 'year', vehicleInfo.year) || 0) || null,
    vehicle_color: pick(row, 'color', vehicleInfo.color), date_of_birth: pick(row, 'dob', personal.dateOfBirth) || null,
    sex: pick(row, 'sex', 'gender', personal.sex), barangay: pick(row, 'barangay'),
    municipality: pick(row, 'municipality'), province: pick(row, 'province'),
    toda_id: todaId,
    current_latitude: pick(row, 'latitude') ?? row.currentLocation?.latitude ?? null,
    current_longitude: pick(row, 'longitude') ?? row.currentLocation?.longitude ?? null,
    last_location_at: iso(pick(row, 'locationUpdatedAt', 'location_updated_at')),
    rating_average: Number(pick(row, 'rating', 'ratingAverage') || 0) || null,
    rating_count: Number(pick(row, 'ratingCount', 'rating_count') || 0),
    rejection_reason: pick(row, 'rejectionReason', 'rejection_reason'),
    submitted_at: iso(pick(row, 'submittedAt', 'submitted_at', 'createdAt')) || new Date().toISOString(),
  };
});
report.tables.drivers = await upsertBatches(client, 'drivers', drivers, 'user_id');

const passengerProfiles = asArray(exported, 'passengers').map((row) => {
  const userId = mapped(
    pick(row, 'userId', 'user_id', '__firebase_id'),
    `passenger ${row.__firebase_id}`,
    true,
  );
  if (!userId) return null;
  return {
    user_id: userId,
    ride_count: Number(pick(row, 'rideCount', 'ride_count') || 0),
    default_address: pick(row, 'defaultAddress', 'formattedAddress'),
    saved_addresses: pick(row, 'savedAddresses', 'saved_addresses') || [],
    emergency_contacts: pick(row, 'emergencyContacts', 'emergency_contacts') || [],
    payment_methods: pick(row, 'paymentMethods', 'payment_methods') || [],
  };
}).filter(Boolean);
report.tables.passenger_profiles = await upsertBatches(client, 'passenger_profiles', passengerProfiles, 'user_id');

const rides = asArray(exported, 'rides').map((row) => ({
  id: String(pick(row, 'id', '__firebase_id')),
  passenger_id: mapped(pick(row, 'passenger_id', 'passengerId'), `ride passenger ${row.__firebase_id}`),
  driver_id: mapped(pick(row, 'driver_id', 'driverId'), `ride driver ${row.__firebase_id}`, true),
  passenger_name: pick(row, 'passenger_name', 'passengerName') || '', passenger_phone: pick(row, 'passenger_phone', 'passengerPhone') || '',
  vehicle_type: vehicle(pick(row, 'vehicle_type', 'vehicleType')),
  pickup_address: pick(row, 'pickup_address', 'pickupAddress') || '',
  pickup_latitude: Number(pick(row, 'pickup_lat') ?? row.pickupLocation?.latitude ?? row.pickup_location?.latitude ?? 0),
  pickup_longitude: Number(pick(row, 'pickup_lng') ?? row.pickupLocation?.longitude ?? row.pickup_location?.longitude ?? 0),
  pickup_province: pick(row, 'pickupProvince', 'pickup_province'),
  destination_address: pick(row, 'dropoff_address', 'destinationAddress', 'dropoffAddress') || '',
  destination_latitude: Number(pick(row, 'dropoff_lat') ?? row.destinationLocation?.latitude ?? row.dropoffLocation?.latitude ?? 0),
  destination_longitude: Number(pick(row, 'dropoff_lng') ?? row.destinationLocation?.longitude ?? row.dropoffLocation?.longitude ?? 0),
  destination_province: pick(row, 'destinationProvince', 'destination_province'),
  distance_km: Number(pick(row, 'distance_km', 'distanceKm') || 0), duration_minutes: Number(pick(row, 'duration_min', 'durationMin') || 0),
  fare: Number(pick(row, 'fare', 'estimatedFare') || 0), commission: Number(pick(row, 'commission') || 0),
  driver_net: Number(pick(row, 'net', 'driverNet') || 0), status: rideStatus(pick(row, 'status')),
  payment_method: pick(row, 'payment_method', 'paymentMethod') || 'cash', payment_status: pick(row, 'payment_status', 'paymentStatus') || 'unpaid',
  queued: bool(pick(row, 'queued')), created_at: iso(pick(row, 'created_at', 'createdAt')) || new Date().toISOString(),
  accepted_at: iso(pick(row, 'accepted_at', 'acceptedAt')), arrived_at: iso(pick(row, 'arrived_at', 'arrivedAt')),
  started_at: iso(pick(row, 'started_at', 'startedAt')), completed_at: iso(pick(row, 'completed_at', 'completedAt')),
  cancelled_at: iso(pick(row, 'cancelled_at', 'cancelledAt')), cancellation_reason: pick(row, 'cancellation_reason', 'cancellationReason'),
}));
report.tables.rides = await upsertBatches(client, 'rides', rides, 'id');

const simpleTransforms = [
  ['bookings', 'bookings', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    passenger_id: mapped(pick(row, 'passenger_id', 'passengerId'), `booking ${row.__firebase_id}`),
    vehicle_type: vehicle(pick(row, 'vehicle_type', 'vehicleType')),
    pickup_address: pick(row, 'pickup_address', 'pickupAddress') || '',
    destination_address: pick(row, 'dropoff_address', 'destinationAddress', 'dropoffAddress') || '',
    pickup_latitude: Number(pick(row, 'pickup_lat') ?? row.pickupLocation?.latitude ?? 0),
    pickup_longitude: Number(pick(row, 'pickup_lng') ?? row.pickupLocation?.longitude ?? 0),
    destination_latitude: Number(pick(row, 'dropoff_lat') ?? row.destinationLocation?.latitude ?? 0),
    destination_longitude: Number(pick(row, 'dropoff_lng') ?? row.destinationLocation?.longitude ?? 0),
    payment_method: pick(row, 'payment_method', 'paymentMethod') || 'cash',
    status: pick(row, 'status') || 'requested', queued: bool(pick(row, 'queued')),
    created_at: iso(pick(row, 'created_at', 'createdAt')) || new Date().toISOString(),
  })],
  ['chat_messages', 'chat_messages', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    ride_id: String(pick(row, 'trip_id', 'tripId', 'ride_id', 'rideId')),
    sender_id: mapped(pick(row, 'sender_id', 'senderId'), `chat sender ${row.__firebase_id}`),
    sender_role: bool(pick(row, 'is_driver', 'isDriver')) ? 'driver' : (pick(row, 'sender_role', 'senderRole') || 'passenger'),
    body: pick(row, 'text', 'body') || '', is_read: bool(pick(row, 'is_read', 'isRead')),
    created_at: iso(pick(row, 'timestamp', 'created_at', 'createdAt')) || new Date().toISOString(),
  })],
  ['transactions', 'wallet_transactions', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    user_id: mapped(pick(row, 'driver_id', 'driverId', 'user_id', 'userId'), `transaction ${row.__firebase_id}`),
    ride_id: pick(row, 'trip_id', 'tripId', 'ride_id', 'rideId'), type: pick(row, 'type') || 'income',
    amount: Number(pick(row, 'amount') || 0), description: pick(row, 'description') || '',
    status: pick(row, 'status') || 'completed', created_at: iso(pick(row, 'created_at', 'createdAt')) || new Date().toISOString(),
  })],
  ['ratings', 'ratings', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    ride_id: String(pick(row, 'rideId', 'ride_id', 'tripId', 'trip_id')),
    passenger_id: mapped(pick(row, 'fromUserId', 'reviewerId', 'passenger_id', 'passengerId'), `rating passenger ${row.__firebase_id}`),
    driver_id: mapped(pick(row, 'toUserId', 'revieweeId', 'driver_id', 'driverId'), `rating driver ${row.__firebase_id}`),
    rating: Math.max(1, Math.min(5, Number(pick(row, 'stars', 'rating') || 1))),
    comment: pick(row, 'comment', 'review') || '', created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
  })],
  ['payments', 'payments', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')), ride_id: String(pick(row, 'rideId', 'ride_id')),
    passenger_id: mapped(pick(row, 'payerId', 'passenger_id', 'passengerId'), `payment payer ${row.__firebase_id}`),
    driver_id: mapped(pick(row, 'payeeId', 'driver_id', 'driverId'), `payment payee ${row.__firebase_id}`, true),
    amount: Number(pick(row, 'amount') || 0), platform_fee: Number(pick(row, 'commission', 'platformFee') || 0),
    driver_net: Number(pick(row, 'net', 'driverNet') || 0), method: pick(row, 'method') || 'cash',
    provider: pick(row, 'provider'), provider_reference: pick(row, 'reference', 'referenceNumber'),
    status: pick(row, 'status') || 'unpaid', metadata: { session_id: pick(row, 'sessionId'), checkout_url: pick(row, 'checkoutUrl') },
    created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
    paid_at: iso(pick(row, 'verifiedAt', 'paidAt')), updated_at: iso(pick(row, 'updatedAt', 'updated_at')) || new Date().toISOString(),
  })],
  ['driver_earnings', 'driver_earnings', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    driver_id: mapped(pick(row, 'driverId', 'driver_id'), `earning ${row.__firebase_id}`),
    ride_id: pick(row, 'rideId', 'ride_id'), gross_amount: Number(pick(row, 'fare', 'gross_amount') || 0),
    commission: Number(pick(row, 'commission') || 0), net_amount: Number(pick(row, 'net', 'net_amount') || 0),
    created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
  })],
  ['withdrawals', 'withdrawals', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    driver_id: mapped(pick(row, 'driverId', 'driver_id'), `withdrawal ${row.__firebase_id}`),
    amount: Number(pick(row, 'amount') || 0), method: pick(row, 'method') || 'gcash',
    account_details: { reference: pick(row, 'reference'), note: pick(row, 'note'), ...(row.accountDetails || {}) },
    status: pick(row, 'status') || 'pending', requested_at: iso(pick(row, 'createdAt', 'requested_at')) || new Date().toISOString(),
    processed_at: iso(pick(row, 'processedAt', 'processed_at')),
  })],
  ['toda_associations', 'toda_associations', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')), toda_id: String(pick(row, 'todaId', 'toda_id')),
    driver_id: mapped(pick(row, 'driverId', 'driver_id'), `TODA association ${row.__firebase_id}`),
    status: pick(row, 'status') === 'removed' ? 'rejected' : (pick(row, 'status') || 'pending'),
    member_role: pick(row, 'role') || 'member', created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
  })],
  ['reports', 'reports', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    reporter_id: mapped(pick(row, 'reporterId', 'reporter_id'), `report reporter ${row.__firebase_id}`),
    reporter_name: pick(row, 'reporterName', 'reporter_name') || 'Unknown', reporter_role: pick(row, 'reporterRole', 'reporter_role') || 'passenger',
    reporter_mobile: pick(row, 'reporterMobile', 'reporter_mobile'),
    reported_user_id: mapped(pick(row, 'reportedUserId', 'reported_user_id'), `report subject ${row.__firebase_id}`, true),
    reported_user_name: pick(row, 'reportedUserName', 'reported_user_name'), reported_user_role: pick(row, 'reportedUserRole', 'reported_user_role'),
    ride_id: pick(row, 'rideId', 'ride_id'), type: pick(row, 'type') || 'other', title: pick(row, 'title') || 'Report',
    description: pick(row, 'description') || '', status: pick(row, 'status') || 'pending', priority: pick(row, 'priority') || 'normal',
    admin_notes: pick(row, 'adminNotes', 'admin_notes') || [], resolution_summary: pick(row, 'resolutionSummary', 'resolution_summary'),
    resolved_by: mapped(pick(row, 'resolvedByAdminId', 'resolved_by_admin_id'), `report resolver ${row.__firebase_id}`, true),
    created_at: iso(pick(row, 'createdAt', 'created_at')) || new Date().toISOString(),
    updated_at: iso(pick(row, 'updatedAt', 'updated_at')) || new Date().toISOString(), resolved_at: iso(pick(row, 'resolvedAt', 'resolved_at')),
  })],
  ['notifications', 'notifications', (row) => ({
    id: String(pick(row, 'id', '__firebase_id')),
    user_id: mapped(pick(row, 'user_id', 'userId'), `notification ${row.__firebase_id}`),
    sender_id: mapped(pick(row, 'sender_id', 'senderId'), `notification sender ${row.__firebase_id}`, true),
    ride_id: pick(row, 'trip_id', 'rideId'), type: pick(row, 'type') || 'general',
    title: pick(row, 'title') || '', body: pick(row, 'body') || '', payload: pick(row, 'payload') || {},
    is_read: bool(pick(row, 'isRead', 'is_read', 'read')), created_at: iso(pick(row, 'created_at', 'createdAt')) || new Date().toISOString(),
  })],
  ['fare_matrix', 'fare_config', (row) => ({
    vehicle_type: vehicle(pick(row, 'vehicleType', 'vehicle_type', 'id', '__firebase_id')),
    base_fare: Number(pick(row, 'baseFare', 'base_fare') || 0), base_km: Number(pick(row, 'baseKm', 'base_km') || 1),
    per_km_rate: Number(pick(row, 'perKmRate', 'perKm', 'per_km_rate') || 0),
    commission_percent: (() => {
      const value = Number(pick(row, 'commissionPercent', 'commission_percent', 'commissionRate') || 12);
      return value > 0 && value <= 1 ? value * 100 : value;
    })(),
    night_diff_percent: Number(pick(row, 'nightDiffPercent', 'night_diff_percent') || 0),
    senior_discount_percent: Number(pick(row, 'seniorDiscountPercent', 'senior_discount_percent') || 20),
    student_discount_percent: Number(pick(row, 'studentDiscountPercent', 'student_discount_percent') || 20),
    pwd_discount_percent: Number(pick(row, 'pwdDiscountPercent', 'pwd_discount_percent') || 20),
    effective_at: iso(pick(row, 'effectiveDate', 'effective_date')) || new Date().toISOString(),
  })],
];
for (const [source, table, transform] of simpleTransforms) {
  let rows = asArray(exported, source).map(transform);
  if (table === 'ratings' || table === 'payments') {
    const uniqueByRide = new Map();
    for (const row of rows) {
      if (uniqueByRide.has(row.ride_id)) {
        report.skipped.push({ context: `${table} ${row.id}`, reason: `duplicate ride_id ${row.ride_id}; latest record retained` });
      }
      uniqueByRide.set(row.ride_id, row);
    }
    rows = [...uniqueByRide.values()];
  }
  report.tables[table] = await upsertBatches(client, table, rows, table === 'fare_config' ? 'vehicle_type' : 'id');
}

report.completed_at = new Date().toISOString();
await writeJson(path.join(directory, 'import-report.json'), report);
process.stdout.write(`${JSON.stringify(report.tables, null, 2)}\n`);
