import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const bucket = 'driver-documents';
const allowedKinds = ['profile', 'license_front', 'or_cr'] as const;
type DocumentKind = typeof allowedKinds[number];

class HttpError extends Error {
  constructor(message: string, readonly status = 400) {
    super(message);
  }
}

function response(request: Request, value: unknown, status = 200) {
  const origin = request.headers.get('Origin') ?? '*';
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
      'Content-Type': 'application/json',
    },
  });
}

function requiredString(value: unknown, label: string, maxLength = 500): string {
  if (typeof value !== 'string') throw new HttpError(`${label} is required.`);
  const result = value.trim();
  if (!result || result.length > maxLength) throw new HttpError(`${label} is invalid.`);
  return result;
}

function requiredVehicleColor(value: unknown): string {
  if (typeof value !== 'string' || !value.trim()) {
    throw new HttpError('Vehicle color is required.');
  }
  const color = value.trim();
  if ([...color].length > 60) {
    throw new HttpError('Vehicle color must be 60 characters or fewer.');
  }
  return color;
}

function optionalString(value: unknown, maxLength = 500): string | null {
  if (value == null) return null;
  if (typeof value !== 'string' || value.trim().length > maxLength) {
    throw new HttpError('An optional application field is invalid.');
  }
  return value.trim() || null;
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function isValidDateOnly(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return value.slice(0, 4) !== '0000' && Number.isFinite(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === value;
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function clients(request: Request) {
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) {
    throw new HttpError('Driver application service is not configured.', 503);
  }
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const authorization = request.headers.get('Authorization');
  return { admin, anonKey, authorization };
}

async function authenticatedUser(
  request: Request,
  admin: SupabaseClient,
  anonKey: string,
  required: boolean,
  allowUnverifiedOptionalSession = false,
) {
  const authorization = request.headers.get('Authorization');
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token || token === anonKey) {
    if (required) throw new HttpError('Authentication required.', 401);
    return null;
  }
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) {
    if (!required && allowUnverifiedOptionalSession) {
      // Application submission is intentionally available before a Driver
      // account exists. Supabase Flutter can still attach a stale session
      // token, so treat only this optional identity as anonymous; never trust
      // the unverified token or use this fallback for Admin operations.
      console.warn(
        '[driver-applications] begin received an unverifiable optional session; continuing anonymously',
      );
      return null;
    }
    throw new HttpError('The submitted session could not be verified.', 401);
  }
  return data.user;
}

async function requireAdmin(request: Request, admin: SupabaseClient, anonKey: string) {
  const user = await authenticatedUser(request, admin, anonKey, true);
  const { data: role, error } = await admin.from('admin_roles')
    .select('role,status').eq('user_id', user!.id).maybeSingle();
  if (error) throw error;
  if (!role || role.status !== 'active' || !['admin', 'super_admin'].includes(role.role)) {
    throw new HttpError('Administrator authorization required.', 403);
  }
  return user!;
}

async function verifyApplicantToken(
  admin: SupabaseClient,
  applicationId: unknown,
  token: unknown,
) {
  if (!isUuid(applicationId) || typeof token !== 'string' || token.length < 32 || token.length > 160) {
    throw new HttpError('Application status receipt is invalid.', 404);
  }
  const { data: application, error } = await admin.from('driver_applications')
    .select('*').eq('id', applicationId).maybeSingle();
  if (error) throw error;
  if (!application || application.status_token_hash !== await sha256Hex(token)) {
    throw new HttpError('Application status receipt is invalid.', 404);
  }
  return application;
}

function normalizedApplication(body: Record<string, unknown>, authUserId: string | null) {
  const email = requiredString(body.email, 'Email', 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError('Enter a valid email address.');
  const vehicleType = requiredString(body.vehicle_type, 'Vehicle type', 20);
  if (!['tricycle', 'habal'].includes(vehicleType)) throw new HttpError('Vehicle type is invalid.');
  const todaId = optionalString(body.toda_id, 100);
  if (vehicleType === 'tricycle' && !todaId) throw new HttpError('Select an active TODA for a tricycle application.');
  if (vehicleType === 'habal' && todaId) throw new HttpError('Habal-Habal applications must not include a TODA.');
  const dateOfBirth = requiredString(body.date_of_birth, 'Date of birth', 10);
  if (!isValidDateOnly(dateOfBirth)) {
    throw new HttpError('Date of birth is invalid.');
  }
  const year = Number(body.vehicle_year);
  if (!Number.isInteger(year) || year < 1950 || year > new Date().getUTCFullYear() + 1) {
    throw new HttpError('Vehicle year is invalid.');
  }
  const licenseType = optionalString(body.license_type, 40);
  const licenseNumber = optionalString(body.license_number, 100);
  const licenseExpiry = optionalString(body.license_expiry, 10);
  if ((licenseNumber || licenseExpiry) && !licenseType) {
    throw new HttpError('Select a license type when license details are provided.');
  }
  if (licenseExpiry && !isValidDateOnly(licenseExpiry)) {
    throw new HttpError('License expiry date is invalid.');
  }
  const mobile = requiredString(body.mobile, 'Mobile number', 32);
  if (mobile.replace(/\D/g, '').length < 7) throw new HttpError('Mobile number is invalid.');
  return {
    full_name: requiredString(body.full_name, 'Full name', 160),
    email,
    mobile,
    address: requiredString(body.address, 'Address', 500),
    date_of_birth: dateOfBirth,
    sex: requiredString(body.sex, 'Sex', 32),
    vehicle_type: vehicleType,
    plate_number: requiredString(body.plate_number, 'Plate number', 60),
    vehicle_make: requiredString(body.vehicle_make, 'Vehicle make', 80),
    vehicle_model: requiredString(body.vehicle_model, 'Vehicle model', 80),
    vehicle_year: year,
    vehicle_color: requiredVehicleColor(body.vehicle_color),
    license_type: licenseType,
    license_number: licenseNumber,
    license_expiry: licenseExpiry,
    dl_codes: optionalString(body.dl_codes, 300),
    condition_codes: optionalString(body.condition_codes, 300),
    toda_id: todaId,
    barangay: requiredString(body.barangay, 'Barangay', 120),
    municipality: requiredString(body.municipality, 'Municipality', 120),
    province: requiredString(body.province, 'Province', 120),
    submitted_by_auth_user_id: authUserId,
    auth_user_id: authUserId,
  };
}

type UploadDescriptor = { content_type: string; extension: string };
function uploadDescriptors(value: unknown): Partial<Record<DocumentKind, UploadDescriptor>> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpError('Document upload details are missing.');
  const input = value as Record<string, unknown>;
  const result: Partial<Record<DocumentKind, UploadDescriptor>> = {};
  for (const kind of allowedKinds) {
    const descriptor = input[kind];
    if (descriptor == null) continue;
    if (typeof descriptor !== 'object' || Array.isArray(descriptor)) throw new HttpError('Document upload details are invalid.');
    const item = descriptor as Record<string, unknown>;
    const contentType = requiredString(item.content_type, 'Document content type', 80).toLowerCase();
    const extension = requiredString(item.extension, 'Document extension', 8).toLowerCase().replace(/^\./, '');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(contentType) || !['jpg', 'jpeg', 'png', 'webp'].includes(extension)) {
      throw new HttpError('Only JPEG, PNG, or WebP application documents are accepted.');
    }
    result[kind] = { content_type: contentType, extension };
  }
  if (!result.profile) throw new HttpError('A profile photo is required.');
  return result;
}

async function checkEligibleToda(admin: SupabaseClient, vehicleType: string, todaId: string | null) {
  if (vehicleType === 'habal') {
    if (todaId) throw new HttpError('Habal-Habal applications must not include a TODA.');
    return;
  }
  if (!todaId) throw new HttpError('Select an active TODA for a tricycle application.');
  const { data, error } = await admin.from('todas').select('id,is_active').eq('id', todaId).maybeSingle();
  if (error) throw error;
  if (!data?.is_active) throw new HttpError('The selected TODA is no longer active. Refresh the list and choose another.', 409);
}

async function reserveRateLimit(admin: SupabaseClient, request: Request, email: string) {
  const ip = request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  const salt = Deno.env.get('DRIVER_APPLICATION_RATE_LIMIT_SALT') ||
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.slice(0, 32);
  if (!salt) {
    console.error('[RateLimit] Critical: neither DRIVER_APPLICATION_RATE_LIMIT_SALT nor service role secret is available.');
    throw new HttpError('Service configuration error.', 500);
  }
  const limits = [
    { key: `ip:${ip}`, limit: 5 },
    { key: `email:${email}`, limit: 3 },
  ];
  for (const item of limits) {
    const keyHash = await sha256Hex(`${salt}:${item.key}`);
    const { data, error } = await admin.rpc('consume_driver_application_rate_limit', {
      p_key_hash: keyHash,
      p_limit: item.limit,
      p_window_seconds: 86400,
    });
    if (error) throw error;
    if (data !== true) throw new HttpError('Too many application attempts. Please try again tomorrow.', 429);
  }
}

async function createUploadGrants(
  admin: SupabaseClient,
  applicationId: string,
  descriptors: Partial<Record<DocumentKind, UploadDescriptor>>,
) {
  const uploads: Array<{ kind: DocumentKind; path: string; token: string; contentType: string }> = [];
  for (const kind of allowedKinds) {
    const descriptor = descriptors[kind];
    if (!descriptor) continue;
    const path = `applications/${applicationId}/${kind}/${kind}.${descriptor.extension}`;
    // The grant is restricted to this one application path. Upsert permits a
    // safe retry if the upload succeeded but the client lost its response.
    const { data, error } = await admin.storage.from(bucket).createSignedUploadUrl(path, { upsert: true });
    if (error || !data?.token) throw error ?? new Error('Unable to prepare a private document upload.');
    uploads.push({ kind, path, token: data.token, contentType: descriptor.content_type });
  }
  return uploads;
}

async function beginApplication(request: Request, body: Record<string, unknown>, admin: SupabaseClient, anonKey: string) {
  const submissionKey = body.submission_key;
  const statusToken = body.status_token;
  if (!isUuid(submissionKey) || typeof statusToken !== 'string' || statusToken.length < 32 || statusToken.length > 160) {
    throw new HttpError('Application receipt could not be initialized. Please retry.');
  }
  const authUser = await authenticatedUser(request, admin, anonKey, false, true);
  const fields = normalizedApplication(body, authUser?.id ?? null);
  if (authUser && authUser.email?.trim().toLowerCase() !== fields.email) {
    throw new HttpError('The application email must match the signed-in account.', 403);
  }
  const descriptors = uploadDescriptors(body.documents);
  await checkEligibleToda(admin, fields.vehicle_type, fields.toda_id);

  const tokenHash = await sha256Hex(statusToken);
  const { data: existing, error: existingError } = await admin.from('driver_applications')
    .select('id,status,status_token_hash,email,doc_profile,doc_license_front,doc_or_cr')
    .eq('submission_key', submissionKey).maybeSingle();
  if (existingError) throw existingError;
  if (existing) {
    if (existing.status_token_hash !== tokenHash || existing.email !== fields.email) {
      throw new HttpError('This application submission key has already been used.', 409);
    }
    const uploads = existing.status === 'uploading'
      ? await createUploadGrants(admin, existing.id, descriptors)
      : [];
    return response(request, { applicationId: existing.id, statusToken, status: existing.status, uploads });
  }

  await reserveRateLimit(admin, request, fields.email);
  if (!authUser) {
    const { data: existingProfile, error: profileError } = await admin.from('profiles')
      .select('id').eq('email', fields.email).maybeSingle();
    if (profileError) throw profileError;
    if (existingProfile) {
      throw new HttpError('This email already has an account. Sign in to that account and submit the driver application while signed in.', 409);
    }
  }

  const applicationId = crypto.randomUUID();
  const paths: Partial<Record<DocumentKind, string>> = {};
  for (const kind of allowedKinds) {
    const descriptor = descriptors[kind];
    if (descriptor) paths[kind] = `applications/${applicationId}/${kind}/${kind}.${descriptor.extension}`;
  }
  const { error } = await admin.from('driver_applications').insert({
    id: applicationId,
    submission_key: submissionKey,
    status_token_hash: tokenHash,
    ...fields,
    doc_profile: paths.profile,
    doc_license_front: paths.license_front ?? null,
    doc_or_cr: paths.or_cr ?? null,
    status: 'uploading',
  });
  if (error?.code === '23505') {
    throw new HttpError('An application with this email is already under review.', 409);
  }
  if (error) throw error;

  try {
    const uploads = await createUploadGrants(admin, applicationId, descriptors);
    return response(request, { applicationId, statusToken, status: 'uploading', uploads }, 201);
  } catch (error) {
    await admin.from('driver_applications').delete().eq('id', applicationId).eq('status', 'uploading');
    throw error;
  }
}

async function finalizeApplication(request: Request, body: Record<string, unknown>, admin: SupabaseClient) {
  const application = await verifyApplicantToken(admin, body.application_id, body.status_token);
  if (application.status === 'pending') return response(request, { status: 'pending', applicationId: application.id });
  if (application.status !== 'uploading') throw new HttpError('This application can no longer be submitted.', 409);
  await checkEligibleToda(admin, application.vehicle_type, application.toda_id);
  const kinds: Array<[DocumentKind, string | null]> = [
    ['profile', application.doc_profile],
    ['license_front', application.doc_license_front],
    ['or_cr', application.doc_or_cr],
  ];
  for (const [kind, path] of kinds) {
    if (!path) continue;
    const folder = `applications/${application.id}/${kind}`;
    const { data, error } = await admin.storage.from(bucket).list(folder, { limit: 20 });
    if (error) throw error;
    const fileName = path.split('/').at(-1);
    if (!data?.some((item) => item.name === fileName)) {
      throw new HttpError(`The ${kind.replace('_', ' ')} document upload is incomplete.`, 409);
    }
  }
  const { error } = await admin.from('driver_applications').update({ status: 'pending', submitted_at: new Date().toISOString() })
    .eq('id', application.id).eq('status', 'uploading');
  if (error) throw error;
  return response(request, { status: 'pending', applicationId: application.id });
}

async function applicationStatus(request: Request, body: Record<string, unknown>, admin: SupabaseClient) {
  const application = await verifyApplicantToken(admin, body.application_id, body.status_token);
  return response(request, {
    applicationId: application.id,
    status: application.status,
    rejectionReason: application.status === 'rejected' ? application.rejection_reason : null,
    reviewedAt: application.reviewed_at,
    activationEmailSent: application.applicant_notification_status === 'sent',
    notificationStatus: application.applicant_notification_status,
  });
}

async function adminList(
  request: Request,
  admin: SupabaseClient,
  anonKey: string,
  status: 'pending' | 'rejected',
) {
  await requireAdmin(request, admin, anonKey);
  let query = admin.from('driver_applications').select('*');
  query = status === 'rejected'
    ? query.eq('status', 'rejected').is('history_cleared_at', null)
    : query.or('status.eq.pending,status.eq.provisioning_failed,status.eq.provisioning,and(status.eq.awaiting_activation,applicant_notification_status.neq.sent)');
  const { data, error } = await query.order('submitted_at', { ascending: false }).limit(500);
  if (error) throw error;
  const rows = data ?? [];
  const todaIds = [...new Set(rows.map((row) => row.toda_id).filter((id): id is string => !!id))];
  const todaById = new Map<string, string>();
  if (todaIds.length) {
    const { data: todas, error: todaError } = await admin.from('todas').select('id,name').in('id', todaIds);
    if (todaError) throw todaError;
    for (const toda of todas ?? []) todaById.set(toda.id, toda.name);
  }
  const reviewerIds = [...new Set(rows.map((row) => row.reviewed_by).filter((id): id is string => !!id))];
  const reviewerById = new Map<string, string>();
  if (reviewerIds.length) {
    const { data: reviewers } = await admin.from('profiles').select('id,full_name').in('id', reviewerIds);
    if (reviewers) {
      for (const r of reviewers) {
        if (r.full_name) reviewerById.set(r.id, r.full_name);
      }
    }
  }
  const result = [];
  for (const row of rows) {
    const signed: Record<string, string | null> = {};
    for (const [field, kind] of [
      ['doc_profile', 'profile'], ['doc_license_front', 'license_front'], ['doc_or_cr', 'or_cr'],
    ] as const) {
      const path = row[field] as string | null;
      if (!path) { signed[field] = null; continue; }
      const { data: object, error: signError } = await admin.storage.from(bucket).createSignedUrl(path, 900);
      if (signError) throw signError;
      signed[field] = object.signedUrl;
    }
    result.push({
      id: row.id,
      full_name: row.full_name,
      email: row.email,
      mobile: row.mobile,
      address: row.address,
      date_of_birth: row.date_of_birth,
      sex: row.sex,
      vehicle_type: row.vehicle_type,
      plate_number: row.plate_number,
      vehicle_make: row.vehicle_make,
      vehicle_model: row.vehicle_model,
      vehicle_year: row.vehicle_year,
      vehicle_color: row.vehicle_color,
      license_type: row.license_type,
      license_number: row.license_number,
      license_expiry: row.license_expiry,
      dl_codes: row.dl_codes,
      condition_codes: row.condition_codes,
      toda_id: row.toda_id,
      barangay: row.barangay,
      municipality: row.municipality,
      province: row.province,
      submitted_at: row.submitted_at,
      rejection_reason: status === 'rejected' ? row.rejection_reason : null,
      reviewed_at: row.reviewed_at,
      reviewed_by: row.reviewed_by ?? null,
      reviewer_name: row.reviewed_by ? (reviewerById.get(row.reviewed_by) ?? null) : null,
      status: row.status,
      applicant_notification_status: row.applicant_notification_status,
      ...signed,
      user_id: row.id,
      toda_name: row.toda_id ? (todaById.get(row.toda_id) ?? null) : null,
      application_status: row.status,
    });
  }
  return response(request, result);
}

async function sendRejectionEmail(application: Record<string, any>, reason: string) {
  const apiKey = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('RESEND_FROM_EMAIL');
  if (!apiKey || !from) return 'not_configured';
  const result = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from,
      to: [application.email],
      subject: 'Update on your Sakay Ta driver application',
      text: `Hello ${application.full_name},\n\nYour Sakay Ta driver application was not approved.\n\nReason: ${reason}\n\nYou may contact Sakay Ta support if you need clarification.`,
    }),
  });
  if (!result.ok) {
    const errorPayload = await result.text().catch(() => 'unknown error');
    console.error(`[EmailService] Rejection email Resend API error (status ${result.status}): ${errorPayload}`);
    return 'failed';
  }
  return 'sent';
}

async function sendActivationEmail(
  application: Record<string, any>,
  admin: SupabaseClient,
): Promise<'sent' | 'failed' | 'not_configured'> {
  const apiKey = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('RESEND_FROM_EMAIL');
  if (!apiKey || !from) return 'not_configured';

  try {
    const redirectTo = Deno.env.get('DRIVER_ACTIVATION_REDIRECT') ?? 'sakayta://auth/reset-password';
    const { data, error } = await admin.auth.admin.generateLink({
      type: 'recovery',
      email: String(application.email).toLowerCase(),
      options: { redirectTo },
    });
    const actionLink = data?.properties?.action_link;
    if (error || typeof actionLink !== 'string' || !actionLink) {
      console.error('[EmailService] Failed to generate activation recovery link:', error);
      return 'failed';
    }

    const result = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from,
        to: [application.email],
        subject: 'Set your Sakay Ta Driver account password',
        text: `Hello ${application.full_name},\n\nYour Sakay Ta Driver application is approved. Use this secure link to set your password and activate your account:\n\n${actionLink}\n\nYour account will stay offline until you choose to go online.`,
      }),
    });
    if (!result.ok) {
      const errorPayload = await result.text().catch(() => 'unknown error');
      console.error(`[EmailService] Activation email Resend API error (status ${result.status}): ${errorPayload}`);
      return 'failed';
    }
    return 'sent';
  } catch (err) {
    console.error('[EmailService] Activation email dispatch exception:', err);
    return 'failed';
  }
}

async function rejectApplication(
  request: Request,
  applicationId: string,
  reason: string,
  reviewerId: string,
  admin: SupabaseClient,
) {
  if (!isUuid(applicationId)) throw new HttpError('Application ID is invalid.');
  if (!reason.trim() || reason.trim().length > 1500) throw new HttpError('Enter a rejection reason of 1,500 characters or fewer.');
  const { data: rejected, error } = await admin.from('driver_applications').update({
    status: 'rejected',
    rejection_reason: reason.trim(),
    reviewed_at: new Date().toISOString(),
    reviewed_by: reviewerId,
    provisioning_error: null,
  }).eq('id', applicationId).eq('status', 'pending').select('*').maybeSingle();
  if (error) throw error;
  if (!rejected) {
    const { data: current, error: readError } = await admin.from('driver_applications')
      .select('status').eq('id', applicationId).maybeSingle();
    if (readError) throw readError;
    if (!current) throw new HttpError('Driver application not found.', 404);
    if (current.status === 'rejected') return response(request, { status: 'rejected', alreadyReviewed: true });
    throw new HttpError(`This application is ${current.status} and cannot be rejected now.`, 409);
  }
  const notificationStatus = await sendRejectionEmail(rejected, reason.trim()).catch((err) => {
    console.error('[EmailService] Rejection email dispatch crashed:', err);
    return 'failed';
  });
  await admin.from('driver_applications').update({ applicant_notification_status: notificationStatus }).eq('id', applicationId);

  const authUserId = (rejected.auth_user_id || rejected.submitted_by_auth_user_id) as string | null;
  if (authUserId) {
    try {
      // Only clean up driver-specific records. Always preserve the user's passenger
      // profile, ride history, notifications, and authentication account!
      await admin.from('driver_online_sessions').delete().eq('driver_id', authUserId);
      await admin.from('driver_presence').delete().eq('driver_id', authUserId);
      await admin.from('drivers').delete().eq('user_id', authUserId);
      await admin.from('driver_documents').delete().eq('driver_id', authUserId);
      await admin.from('user_roles').delete().eq('user_id', authUserId).eq('role', 'driver');
    } catch (cleanupError) {
      console.warn('Post-rejection driver cleanup error:', cleanupError);
    }
  }

  return response(request, { status: 'rejected', alreadyReviewed: false, notificationStatus });
}

async function writeAccountForApprovedApplication(
  application: Record<string, any>,
  reviewerId: string,
  claimStartedAt: string,
  admin: SupabaseClient,
) {
  const email = String(application.email).toLowerCase();
  let authUserId = (application.auth_user_id as string | null) || (application.submitted_by_auth_user_id as string | null);
  let existingIdentity = !!authUserId;
  let activationNotificationStatus = String(application.applicant_notification_status ?? 'not_sent');
  let activationNotificationAttempted = false;

  if (application.submitted_by_auth_user_id) {
    authUserId = application.submitted_by_auth_user_id;
    const { data: existingAdmin, error: adminError } = await admin.from('admin_roles')
      .select('user_id').eq('user_id', authUserId).maybeSingle();
    if (adminError) throw adminError;
    if (existingAdmin) throw new HttpError('An Admin identity cannot be provisioned as a Driver.', 409);
  }

  if (!authUserId) {
    const { data: existingProfile, error: profileLookupError } = await admin.from('profiles')
      .select('id').eq('email', email).maybeSingle();
    if (profileLookupError) throw profileLookupError;
    if (existingProfile) {
      const { data: authResult, error: authLookupError } = await admin.auth.admin.getUserById(existingProfile.id);
      if (authLookupError) throw authLookupError;
      const applicationMarker = authResult.user?.user_metadata?.driver_application_id;
      if (applicationMarker !== application.id) {
        throw new HttpError('This email belongs to an existing account. The applicant must sign in and submit using that account.', 409);
      }
      authUserId = existingProfile.id;
      existingIdentity = true;
    } else {
      const redirectTo = Deno.env.get('DRIVER_ACTIVATION_REDIRECT') ?? 'sakayta://auth/reset-password';
      const { data: invitation, error: inviteError } = await admin.auth.admin.inviteUserByEmail(email, {
        data: {
          full_name: application.full_name,
          mobile: application.mobile,
          driver_application_id: application.id,
          driver_account_activated: false,
        },
        redirectTo,
      });
      if (inviteError || !invitation.user) {
        // A retry may race an invite that Auth already committed. Adopt it
        // only when its server-written metadata proves this exact application.
        const { data: profileAfterInviteRace, error: raceLookupError } = await admin.from('profiles')
          .select('id').eq('email', email).maybeSingle();
        if (raceLookupError) throw raceLookupError;
        if (!profileAfterInviteRace) {
          throw inviteError ?? new HttpError('Driver invitation could not be created.');
        }
        const { data: authAfterRace, error: authAfterRaceError } = await admin.auth.admin.getUserById(profileAfterInviteRace.id);
        if (authAfterRaceError) throw authAfterRaceError;
        if (authAfterRace.user?.user_metadata?.driver_application_id !== application.id) {
          throw inviteError ?? new HttpError('Driver invitation could not be created.');
        }
        authUserId = profileAfterInviteRace.id;
        activationNotificationStatus = await sendActivationEmail(application, admin);
        activationNotificationAttempted = true;
      } else {
        authUserId = invitation.user.id;
        activationNotificationStatus = 'sent';
      }
    }
  }

  const { error: linkError } = await admin.from('driver_applications').update({ auth_user_id: authUserId })
    .eq('id', application.id).eq('status', 'provisioning');
  if (linkError) throw linkError;

  const { data: profile, error: profileReadError } = await admin.from('profiles')
    .select('id,account_status').eq('id', authUserId).maybeSingle();
  if (profileReadError) throw profileReadError;
  if (profile && ['deactivated', 'suspended'].includes(profile.account_status)) {
    throw new HttpError('The linked account is deactivated and cannot be approved as a Driver.', 409);
  }
  const profileStatus = (profile && ['deactivated', 'suspended'].includes(profile.account_status))
    ? profile.account_status
    : 'approved';
  const { error: profileWriteError } = await admin.from('profiles').upsert({
    id: authUserId,
    full_name: application.full_name,
    email,
    mobile: application.mobile,
    address: application.address,
    account_status: profileStatus,
  }, { onConflict: 'id' });
  if (profileWriteError) throw profileWriteError;

  const { data: existingDriver, error: driverLookupError } = await admin.from('drivers')
    .select('user_id,approved_application_id').eq('user_id', authUserId).maybeSingle();
  if (driverLookupError) throw driverLookupError;
  if (existingDriver && existingDriver.approved_application_id !== application.id) {
    throw new HttpError('This identity already has a Driver profile. No existing Driver data was changed.', 409);
  }
  const driverStatus = 'approved';
  const { error: driverWriteError } = await admin.from('drivers').upsert({
    user_id: authUserId,
    approved_application_id: application.id,
    application_status: driverStatus,
    is_online: false,
    is_available: false,
    vehicle_type: application.vehicle_type,
    plate_number: application.plate_number,
    license_type: application.license_type,
    license_number: application.license_number,
    license_expiry: application.license_expiry,
    dl_codes: application.dl_codes,
    condition_codes: application.condition_codes,
    vehicle_make: application.vehicle_make,
    vehicle_model: application.vehicle_model,
    vehicle_year: application.vehicle_year,
    vehicle_color: application.vehicle_color,
    date_of_birth: application.date_of_birth,
    sex: application.sex,
    barangay: application.barangay,
    municipality: application.municipality,
    province: application.province,
    toda_id: application.toda_id,
    submitted_at: application.submitted_at,
  }, { onConflict: 'user_id' });
  if (driverWriteError) throw driverWriteError;

  const documents = [
    ['profile', application.doc_profile],
    ['license_front', application.doc_license_front],
    ['or_cr', application.doc_or_cr],
  ] as const;
  for (const [type, path] of documents) {
    if (!path) continue;
    const { error } = await admin.from('driver_documents').upsert({
      driver_id: authUserId,
      document_type: type,
      storage_path: path,
    }, { onConflict: 'driver_id,document_type,storage_path', ignoreDuplicates: true });
    if (error) throw error;
  }

  if (application.doc_profile) {
    try {
      const { data: photoBlob, error: photoErr } = await admin.storage
        .from('driver-documents')
        .download(application.doc_profile);
      if (!photoErr && photoBlob) {
        const avatarPath = `${authUserId}/profile.jpg`;
        const buffer = Buffer.from(await photoBlob.arrayBuffer());
        await admin.storage.from('avatars').upload(avatarPath, buffer, {
          contentType: 'image/jpeg',
          upsert: true,
        });
        await admin.from('profiles').update({
          profile_photo_path: avatarPath,
        }).eq('id', authUserId);
      }
    } catch (photoSyncError) {
      console.warn('Failed to sync driver profile photo to avatars:', photoSyncError);
    }
  }

  if (!existingIdentity && activationNotificationStatus !== 'sent' && !activationNotificationAttempted) {
    activationNotificationStatus = await sendActivationEmail(application, admin);
    activationNotificationAttempted = true;
  }

  const finalStatus = existingIdentity ? 'approved' : 'awaiting_activation';
  const { error: finalizeError } = await admin.from('driver_applications').update({
    status: finalStatus,
    auth_user_id: authUserId,
    reviewed_by: reviewerId,
    provisioning_error: null,
    applicant_notification_status: existingIdentity ? 'not_sent' : activationNotificationStatus,
  }).eq('id', application.id).eq('status', 'provisioning')
    .eq('provisioning_started_at', claimStartedAt).select('id').maybeSingle();
  if (finalizeError) throw finalizeError;
  if (!finalizeError) {
    const { data: finalizedRow, error: finalizedReadError } = await admin.from('driver_applications')
      .select('id').eq('id', application.id).eq('status', finalStatus)
      .eq('provisioning_started_at', claimStartedAt).maybeSingle();
    if (finalizedReadError) throw finalizedReadError;
    if (!finalizedRow) throw new HttpError('This approval attempt was superseded. Review the application status before retrying.', 409);
  }

  await admin.from('notifications').upsert({
    id: `driver_application_${application.id}`,
    user_id: authUserId,
    sender_id: reviewerId,
    type: 'driver_verification',
    title: 'Driver Application Approved',
    body: 'Your driver application was approved. Your Driver profile is offline until you choose to go online.',
  }, { onConflict: 'id', ignoreDuplicates: true });

  return {
    status: finalStatus,
    authUserId,
    activationEmailSent: !existingIdentity && activationNotificationStatus === 'sent',
    notificationStatus: existingIdentity ? 'not_sent' : activationNotificationStatus,
  };
}

async function approveApplication(
  request: Request,
  applicationId: string,
  reviewerId: string,
  admin: SupabaseClient,
) {
  if (!isUuid(applicationId)) throw new HttpError('Application ID is invalid.');
  let { data: application, error } = await admin.from('driver_applications').select('*')
    .eq('id', applicationId).maybeSingle();
  if (error) throw error;
  if (!application) throw new HttpError('Driver application not found.', 404);
  if (application.status === 'active' || application.status === 'approved') {
    return response(request, {
      status: application.status,
      alreadyProvisioned: true,
      activationEmailSent: application.applicant_notification_status === 'sent',
      notificationStatus: application.applicant_notification_status,
    });
  }
  if (application.status === 'awaiting_activation') {
    if (application.applicant_notification_status === 'sent') {
      return response(request, {
        status: 'awaiting_activation',
        alreadyProvisioned: true,
        activationEmailSent: true,
        notificationStatus: 'sent',
      });
    }

    const now = new Date();
    const updatedAt = Date.parse(application.updated_at ?? '');
    if (application.applicant_notification_status === 'sending' &&
        Number.isFinite(updatedAt) && now.getTime() - updatedAt < 5 * 60 * 1000) {
      throw new HttpError('Another Admin is retrying the activation email. Refresh and try again in a few minutes.', 409);
    }
    const { data: claimed, error: claimError } = await admin.from('driver_applications').update({
      applicant_notification_status: 'sending',
    }).eq('id', applicationId).eq('status', 'awaiting_activation')
      .eq('applicant_notification_status', application.applicant_notification_status)
      .eq('updated_at', application.updated_at).select('id,updated_at').maybeSingle();
    if (claimError) throw claimError;
    if (!claimed) throw new HttpError('Another Admin is already retrying this activation email. Refresh the application list.', 409);

    const notificationStatus = await sendActivationEmail(application, admin);
    const { data: completed, error: notificationUpdateError } = await admin.from('driver_applications').update({
      applicant_notification_status: notificationStatus,
    }).eq('id', applicationId).eq('status', 'awaiting_activation')
      .eq('applicant_notification_status', 'sending')
      .eq('updated_at', claimed.updated_at).select('id').maybeSingle();
    if (notificationUpdateError) throw notificationUpdateError;
    if (!completed) throw new HttpError('The email attempt finished, but its status changed. Refresh the application before retrying.', 409);
    return response(request, {
      status: 'awaiting_activation',
      alreadyProvisioned: true,
      activationEmailSent: notificationStatus === 'sent',
      notificationStatus,
    });
  }

  const now = new Date();
  const nowIso = now.toISOString();
  if (application.status === 'pending' || application.status === 'provisioning_failed') {
    const previousStatus = application.status;
    const { data: claimed, error: claimError } = await admin.from('driver_applications').update({
      status: 'provisioning',
      provisioning_started_at: nowIso,
      provisioning_attempts: Number(application.provisioning_attempts ?? 0) + 1,
      provisioning_error: null,
      reviewed_by: reviewerId,
      reviewed_at: nowIso,
    }).eq('id', applicationId).eq('status', previousStatus).select('*').maybeSingle();
    if (claimError) throw claimError;
    application = claimed;
  } else if (application.status === 'provisioning') {
    const started = Date.parse(application.provisioning_started_at ?? '');
    if (!Number.isFinite(started) || now.getTime() - started < 5 * 60 * 1000) {
      throw new HttpError('This application is already being provisioned. Retry after a few minutes if it remains unresolved.', 409);
    }
    const { data: claimed, error: claimError } = await admin.from('driver_applications').update({
      provisioning_started_at: nowIso,
      provisioning_attempts: Number(application.provisioning_attempts ?? 0) + 1,
      provisioning_error: null,
      reviewed_by: reviewerId,
    }).eq('id', applicationId).eq('status', 'provisioning')
      .eq('provisioning_started_at', application.provisioning_started_at).select('*').maybeSingle();
    if (claimError) throw claimError;
    if (!claimed) throw new HttpError('Another Admin is already processing this application.', 409);
    application = claimed;
  } else {
    throw new HttpError(`This application is ${application.status} and cannot be approved.`, 409);
  }
  if (!application) throw new HttpError('Another Admin already reviewed this application.', 409);
  const claimStartedAt = application.provisioning_started_at as string | null;
  if (!claimStartedAt) throw new HttpError('The application approval lock could not be established.', 409);

  try {
    await checkEligibleToda(admin, application.vehicle_type, application.toda_id);
    const provisioned = await writeAccountForApprovedApplication(
      application,
      reviewerId,
      claimStartedAt,
      admin,
    );
    return response(request, {
      status: provisioned.status,
      activationEmailSent: provisioned.activationEmailSent,
      notificationStatus: provisioned.notificationStatus,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Driver account provisioning failed.';
    await admin.from('driver_applications').update({
      status: 'provisioning_failed',
      provisioning_error: message.slice(0, 800),
    }).eq('id', applicationId).eq('status', 'provisioning')
      .eq('provisioning_started_at', claimStartedAt);
    throw error;
  }
}

async function activateInvitedDriver(request: Request, admin: SupabaseClient, anonKey: string) {
  const user = await authenticatedUser(request, admin, anonKey, true);
  const { data: application, error } = await admin.from('driver_applications').select('id')
    .eq('auth_user_id', user!.id).in('status', ['awaiting_activation', 'active', 'approved']).maybeSingle();
  if (error) throw error;
  if (!application) return response(request, { activated: false });

  const { data: currentApplication, error: stateError } = await admin.from('driver_applications')
    .select('status').eq('id', application.id).maybeSingle();
  if (stateError) throw stateError;
  if (currentApplication?.status === 'active' || currentApplication?.status === 'approved') {
    const { error: metadataError } = await admin.auth.admin.updateUserById(user!.id, {
      user_metadata: { ...user!.user_metadata, driver_account_activated: true },
    });
    if (metadataError) throw metadataError;
    return response(request, { activated: true });
  }

  const { error: driverError } = await admin.from('drivers').update({
    application_status: 'approved', is_online: false, is_available: false,
  }).eq('user_id', user!.id).eq('approved_application_id', application.id).eq('application_status', 'pending');
  if (driverError) throw driverError;
  const { error: profileError } = await admin.from('profiles').update({ account_status: 'approved' })
    .eq('id', user!.id).eq('account_status', 'pending');
  if (profileError) throw profileError;
  const { error: applicationError } = await admin.from('driver_applications').update({ status: 'approved' })
    .eq('id', application.id).eq('auth_user_id', user!.id).eq('status', 'awaiting_activation');
  if (applicationError) throw applicationError;
  const { error: metadataError } = await admin.auth.admin.updateUserById(user!.id, {
    user_metadata: {
      ...user!.user_metadata,
      driver_account_activated: true,
    },
  });
  if (metadataError) throw metadataError;
  return response(request, { activated: true });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return response(request, { ok: true });
  if (request.method !== 'POST') return response(request, { error: 'Method not allowed.' }, 405);
  try {
    const { admin, anonKey } = clients(request);
    const body = await request.json() as Record<string, unknown>;
    switch (body.action) {
      case 'begin':
        return await beginApplication(request, body, admin, anonKey);
      case 'finalize':
        return await finalizeApplication(request, body, admin);
      case 'status':
        return await applicationStatus(request, body, admin);
      case 'list':
        if (body.status != null && body.status !== 'pending' && body.status !== 'rejected') {
          throw new HttpError('Application list status is invalid.');
        }
        return await adminList(request, admin, anonKey, body.status === 'rejected' ? 'rejected' : 'pending');
      case 'reject': {
        const reviewer = await requireAdmin(request, admin, anonKey);
        const id = requiredString(body.application_id, 'Application ID', 50);
        if (!isUuid(id)) throw new HttpError('Application ID is invalid.');
        const reason = requiredString(body.reason, 'Rejection reason', 1500);
        return await rejectApplication(request, id, reason, reviewer.id, admin);
      }
      case 'approve': {
        const reviewer = await requireAdmin(request, admin, anonKey);
        const id = requiredString(body.application_id, 'Application ID', 50);
        return await approveApplication(request, id, reviewer.id, admin);
      }
      case 'activate':
        return await activateInvitedDriver(request, admin, anonKey);
      case 'clear_rejected': {
        await requireAdmin(request, admin, anonKey);
        const id = requiredString(body.application_id, 'Application ID', 50);
        if (!isUuid(id)) throw new HttpError('Application ID is invalid.');
        const { data, error } = await admin.rpc('clear_rejected_driver_application', { p_application_id: id });
        if (error) throw error;
        return response(request, { cleared: data === true });
      }
      case 'clear_all_rejected': {
        await requireAdmin(request, admin, anonKey);
        const { data, error } = await admin.rpc('clear_all_rejected_driver_applications');
        if (error) throw error;
        return response(request, { count: data ?? 0 });
      }
      default:
        throw new HttpError('Unsupported driver application action.');
    }
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : 'Driver application request failed.';
    return response(request, { error: message }, status);
  }
});
