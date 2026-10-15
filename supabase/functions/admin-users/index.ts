import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type RequestBody = {
  action: 'create' | 'update' | 'delete';
  userId?: string;
  email?: string;
  password?: string;
  fullName?: string;
  role?: 'admin' | 'super_admin';
  status?: 'active' | 'deactivated';
  department?: string;
  permissions?: string[];
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) throw new Error('Authentication required.');
    const url = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !anonKey || !serviceKey) throw new Error('Function environment is incomplete.');

    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const adminClient = createClient(url, serviceKey, { auth: { persistSession: false } });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) throw new Error('Invalid session.');

    const { data: callerRole } = await adminClient.from('admin_roles')
      .select('role,status,permissions').eq('user_id', userData.user.id).maybeSingle();
    if (!callerRole || callerRole.status !== 'active') throw new Error('Administrator authorization required.');

    const body = await request.json() as RequestBody;
    const canManageAdmins = callerRole.role === 'super_admin';
    if (!canManageAdmins) throw new Error('Missing super_admin permission.');

    if (body.action === 'create') {
      if (!body.email || !body.password || !body.fullName) throw new Error('Email, password, and full name are required.');
      if (body.role === 'super_admin') throw new Error('Cannot assign super_admin role during creation. New accounts must be regular admins.');
      const { data, error } = await adminClient.auth.admin.createUser({
        email: body.email.trim().toLowerCase(), password: body.password,
        email_confirm: true, user_metadata: { full_name: body.fullName.trim() },
      });
      if (error || !data.user) throw error || new Error('Auth user was not created.');
      try {
        const { error: profileError } = await adminClient.from('profiles').upsert({
          id: data.user.id, full_name: body.fullName.trim(), email: body.email.trim().toLowerCase(), account_status: 'active',
        });
        if (profileError) throw profileError;
        const { error: roleError } = await adminClient.from('admin_roles').insert({
          user_id: data.user.id, role: body.role || 'admin', status: 'active',
          department: body.department || 'Operations', permissions: body.permissions || [], created_by: userData.user.id,
        });
        if (roleError) throw roleError;
      } catch (error) {
        await adminClient.auth.admin.deleteUser(data.user.id);
        throw error;
      }
      return json({ userId: data.user.id }, 201);
    }

    if (!body.userId) throw new Error('userId is required.');
    if (body.userId === userData.user.id && (body.action === 'delete' || body.status === 'deactivated')) {
      throw new Error('An administrator cannot remove their own active account.');
    }
    const { data: targetRole } = await adminClient.from('admin_roles').select('role').eq('user_id', body.userId).maybeSingle();
    if (targetRole?.role === 'super_admin' && callerRole.role !== 'super_admin') throw new Error('Only a super admin can manage a super admin.');

    if (body.action === 'update') {
      if (body.role === 'super_admin' && callerRole.role !== 'super_admin') throw new Error('Only a super admin can grant super-admin access.');
      const changes: Record<string, unknown> = {};
      if (body.role) changes.role = body.role;
      if (body.status) changes.status = body.status;
      if (body.department) changes.department = body.department;
      if (body.permissions) changes.permissions = body.permissions;
      const { error } = await adminClient.from('admin_roles').update(changes).eq('user_id', body.userId);
      if (error) throw error;
      if (body.fullName || body.email || body.password) {
        if (body.fullName || body.email) {
          const { error: profileError } = await adminClient.from('profiles').update({
            ...(body.fullName ? { full_name: body.fullName.trim() } : {}),
            ...(body.email ? { email: body.email.trim().toLowerCase() } : {}),
          }).eq('id', body.userId);
          if (profileError) throw profileError;
        }
        const { error: authError } = await adminClient.auth.admin.updateUserById(body.userId, {
          ...(body.email ? { email: body.email.trim().toLowerCase() } : {}),
          ...(body.password ? { password: body.password } : {}),
          ...(body.fullName ? { user_metadata: { full_name: body.fullName.trim() } } : {}),
        });
        if (authError) throw authError;
      }
      return json({ updated: true });
    }

    if (body.action === 'delete') {
      const { error } = await adminClient.auth.admin.deleteUser(body.userId);
      if (error) throw error;
      return json({ deleted: true });
    }
    throw new Error('Unsupported action.');
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Request failed.' }, 400);
  }
});

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
