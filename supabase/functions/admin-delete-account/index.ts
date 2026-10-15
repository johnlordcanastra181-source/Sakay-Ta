import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type AccountType = 'passenger' | 'driver';

type RequestBody = {
  targetUserId?: string;
  accountType?: AccountType;
};

type StorageObject = {
  bucket: 'avatars' | 'driver-documents';
  path: string;
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let adminClient: ReturnType<typeof createClient> | null = null;
  let targetUserId = '';
  let auditId: string | null = null;
  let callerUserId = '';
  let accountTypeForAudit: AccountType | null = null;

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) {
      return json({ error: 'Authentication required.' }, 401);
    }

    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) {
      throw new Error('Function environment is incomplete.');
    }

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    adminClient = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: callerData, error: callerError } = await userClient.auth.getUser();
    if (callerError || !callerData.user) throw new Error('Invalid administrator session.');
    callerUserId = callerData.user.id;

    const { data: callerRole, error: roleError } = await adminClient
      .from('admin_roles')
      .select('role,status,permissions')
      .eq('user_id', callerData.user.id)
      .maybeSingle();
    if (roleError) throw roleError;

    const permissions = Array.isArray(callerRole?.permissions)
      ? callerRole.permissions.map((value: unknown) => String(value))
      : [];
    const hasDeletePermission = callerRole?.status === 'active' &&
      (callerRole.role === 'super_admin' ||
        callerRole.role === 'admin' ||
        permissions.includes('all') ||
        permissions.includes('delete_accounts'));
    if (!hasDeletePermission) {
      return json({
        error: 'Missing explicit account-deletion permission.',
        code: 'account_deletion_forbidden',
      }, 403);
    }

    const body = await request.json() as RequestBody;
    targetUserId = String(body.targetUserId ?? '').trim();
    const accountType = body.accountType;
    if (!isUuid(targetUserId)) throw new Error('A valid target account ID is required.');
    if (accountType !== 'passenger' && accountType !== 'driver') {
      throw new Error('A valid account type is required.');
    }
    accountTypeForAudit = accountType;
    if (targetUserId === callerData.user.id) {
      throw new Error('An administrator cannot delete the account currently in use.');
    }

    // A retryable job means the database phase already scrubbed the account.
    // Do not query deleted document rows again or repeat Storage deletion.
    const { data: existingJob, error: jobReadError } = await adminClient
      .from('account_deletion_jobs')
      .select('status,storage_deleted,storage_paths,audit_id,target_account_type')
      .eq('target_user_id', targetUserId)
      .maybeSingle();
    if (jobReadError) throw jobReadError;
    if (existingJob && existingJob.target_account_type !== accountType) {
      throw new Error('The target account type does not match its deletion job.');
    }

    // The RPC runs with the caller's JWT, so its own authorization and
    // transaction are enforced independently of this Edge Function check.
    const { data: preparation, error: preparationError } = await userClient.rpc(
      'admin_prepare_account_deletion',
      {
        target_user: targetUserId,
        target_type: accountType,
      },
    );
    if (preparationError) throw preparationError;
    const prepared = asRecord(preparation);
    auditId = prepared['audit_id']?.toString() ?? null;

    let storageDeleted = existingJob?.storage_deleted === true;
    let storageWarnings = 0;
    if (!storageDeleted) {
      const storagePaths = asRecord(
        prepared['storage_paths'] ?? existingJob?.storage_paths,
      );
      const objects = storageObjectsFromPreparation(
        targetUserId,
        storagePaths,
      );
      storageWarnings = objects.warnings;
      if (storageWarnings > 0) {
        await markFailure(
          adminClient,
          targetUserId,
          auditId ?? '',
          'storage_cleanup_incomplete',
        );
        return json({
          error: 'Storage cleanup could not verify every owned object. Auth deletion was not attempted; retry after resolving the stored path.',
          code: 'storage_cleanup_incomplete',
          partial: true,
        }, 502);
      }
      await removeStorageObjects(adminClient, objects.items);
      storageDeleted = true;
    }

    if (existingJob || prepared['status'] === 'ready_for_auth_deletion' ||
        prepared['status'] === 'completed') {
      const { error: storageStateError } = await adminClient
        .from('account_deletion_jobs')
        .update({ storage_deleted: storageDeleted, updated_at: new Date().toISOString() })
        .eq('target_user_id', targetUserId);
      if (storageStateError) throw storageStateError;
    }

    const { error: authDeleteError } = await adminClient.auth.admin.deleteUser(targetUserId);
    const authAlreadyDeleted = authDeleteError != null && isNotFound(authDeleteError);
    if (authDeleteError && !authAlreadyDeleted) {
      if (auditId) {
        await markFailure(adminClient, targetUserId, auditId, 'auth_delete_failed');
      }
      return json({
        error: 'Database cleanup completed, but Supabase Auth deletion failed. Retry this account deletion safely.',
        code: 'auth_delete_failed',
        partial: true,
      }, 502);
    }

    // If Auth was already removed during a previous attempt, the profile may
    // not have received the Auth cascade.  It is now scrubbed and safe to
    // remove directly; all shared references were nulled by the RPC.
    if (authAlreadyDeleted) {
      const { error: profileDeleteError } = await adminClient
        .from('profiles')
        .delete()
        .eq('id', targetUserId);
      if (profileDeleteError) throw profileDeleteError;
    }

    const { error: completeJobError } = await adminClient
      .from('account_deletion_jobs')
      .update({
        status: 'completed',
        storage_deleted: storageDeleted,
        last_error_code: null,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('target_user_id', targetUserId);
    if (completeJobError) throw completeJobError;

    if (auditId) {
      const { error: auditError } = await adminClient
        .from('account_deletion_audit')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
        })
        .eq('id', auditId);
      if (auditError) throw auditError;
    }

    return json({
      deleted: true,
      targetUserId,
      accountType,
      storageDeleted,
      storageWarnings,
      database: prepared,
      authDeleted: true,
    });
  } catch (error) {
    const message = safeErrorMessage(error);
    const blocked = /missing explicit|administrator account|account-deletion permission|not found|unsupported account|valid target/i.test(message);
    if (adminClient && auditId) {
      await markFailure(
        adminClient,
        targetUserId,
        auditId,
        blocked ? 'deletion_blocked' : 'deletion_failed',
      );
    } else if (adminClient && blocked && accountTypeForAudit && isUuid(targetUserId)) {
      // The SQL transaction rolls back blocked attempts before it can create
      // an audit row, so record the denied attempt without retaining PII.
      await adminClient.from('account_deletion_audit').insert({
        target_user_id: targetUserId,
        target_account_type: accountTypeForAudit,
        initiated_by: callerUserId || null,
        status: 'blocked',
        details: { code: 'deletion_blocked' },
      });
    }
    return json({
      error: message,
      code: blocked ? 'deletion_blocked' : 'deletion_failed',
      partial: Boolean(auditId),
    }, blocked ? 409 : 400);
  }
});

function storageObjectsFromPreparation(
  targetUserId: string,
  storagePaths: Record<string, unknown>,
): { items: StorageObject[]; warnings: number } {
  const items: StorageObject[] = [];
  let warnings = 0;

  const add = (bucket: StorageObject['bucket'], value: unknown) => {
    const path = storagePathFor(bucket, targetUserId, value);
    if (path) {
      items.push({ bucket, path });
    } else if (isSupabaseStorageReference(bucket, value)) {
      warnings += 1;
    }
  };

  const avatars = Array.isArray(storagePaths['avatars'])
    ? storagePaths['avatars']
    : [];
  for (const path of avatars) add('avatars', path);

  const documents = Array.isArray(storagePaths['driver_documents'])
    ? storagePaths['driver_documents']
    : [];
  for (const path of documents) add('driver-documents', path);

  const deduplicated = new Map<string, StorageObject>();
  for (const item of items) deduplicated.set(`${item.bucket}:${item.path}`, item);
  return { items: [...deduplicated.values()], warnings };
}

function storagePathFor(
  bucket: StorageObject['bucket'],
  targetUserId: string,
  value: unknown,
): string | null {
  const raw = String(value ?? '').trim();
  if (!raw) return null;
  let path = raw;
  if (raw.includes('://')) {
    try {
      const segments = new URL(raw).pathname
        .split('/')
        .filter(Boolean)
        .map((segment) => decodeURIComponent(segment));
      const bucketIndex = segments.indexOf(bucket);
      if (bucketIndex === -1) return null;
      path = segments.slice(bucketIndex + 1).join('/');
    } catch (_) {
      return null;
    }
  }
  return (path.startsWith(`${targetUserId}/`) || path.startsWith('applications/')) ? path : null;
}

function isSupabaseStorageReference(
  bucket: StorageObject['bucket'],
  value: unknown,
): boolean {
  const raw = String(value ?? '').trim();
  if (!raw) return false;
  if (!raw.includes('://')) return true;
  try {
    const pathname = new URL(raw).pathname;
    return pathname.includes('/storage/v1/object/') && pathname.includes(`/${bucket}/`);
  } catch (_) {
    return false;
  }
}

async function removeStorageObjects(
  adminClient: ReturnType<typeof createClient>,
  objects: StorageObject[],
) {
  for (const bucket of ['avatars', 'driver-documents'] as const) {
    const paths = objects
      .filter((item) => item.bucket === bucket)
      .map((item) => item.path);
    for (let offset = 0; offset < paths.length; offset += 100) {
      const batch = paths.slice(offset, offset + 100);
      if (batch.length === 0) continue;
      const { error } = await adminClient.storage.from(bucket).remove(batch);
      if (error && !isNotFound(error)) {
        throw new Error(`Storage cleanup failed for ${bucket}.`);
      }
    }
  }
}

async function markFailure(
  adminClient: ReturnType<typeof createClient>,
  targetUserId: string,
  auditId: string,
  code: string,
) {
  const auditStatus = code === 'auth_delete_failed'
    ? 'auth_delete_failed'
    : code === 'deletion_blocked'
      ? 'blocked'
      : 'failed';
  await adminClient.from('account_deletion_jobs').update({
    status: code === 'auth_delete_failed' ? 'auth_delete_failed' : 'db_prepared',
    last_error_code: code,
    updated_at: new Date().toISOString(),
  }).eq('target_user_id', targetUserId);
  await adminClient.from('account_deletion_audit').update({ status: auditStatus }).eq('id', auditId);
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function isNotFound(error: unknown): boolean {
  return /not found|user does not exist|user_not_found/i.test(safeErrorMessage(error));
}

function safeErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (error && typeof error === 'object' && 'message' in error) {
    return String((error as { message?: unknown }).message ?? 'Request failed.');
  }
  return 'Request failed.';
}

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

