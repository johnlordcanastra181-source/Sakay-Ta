import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    // 1. Verify Caller
    const userClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) throw new Error('Invalid session.');

    // 2. Verify Admin Role securely using service_role
    const adminClient = createClient(url, serviceKey, { auth: { persistSession: false } });
    const { data: callerRole } = await adminClient.from('admin_roles')
      .select('role,status')
      .eq('user_id', userData.user.id)
      .maybeSingle();
      
    if (!callerRole || callerRole.status !== 'active' || !['admin', 'super_admin'].includes(callerRole.role)) {
      throw new Error('Administrator authorization required.');
    }

    // 3. Fetch authorized passenger data using the trusted contract
    // We only return the fields required by the Admin UI.
    const { data: passengerProfiles, error: pError } = await adminClient
      .from('passenger_profiles')
      .select('user_id');

    if (pError) throw pError;

    // To prevent hitting URL length limits, we could query profiles directly for passengers.
    // However, since we need to join, we can just fetch all profiles that are passengers.
    // In Supabase, if a foreign key exists, we can join. Assuming no fk, we map.
    const passengerIds = passengerProfiles.map(p => p.user_id);
    
    // Instead of querying in one massive batch, we query the profiles
    // that are actually passengers and format them properly.
    const { data: profiles, error: profError } = await adminClient
      .from('profiles')
      .select('id, full_name, email, mobile, email_verified, created_at, updated_at, account_status, address')
      .in('id', passengerIds);

    if (profError) throw profError;

    // Filter out those who are ALSO admins or drivers to respect the Passenger <-> Admin contract
    const { data: drivers } = await adminClient.from('drivers').select('user_id');
    const { data: admins } = await adminClient.from('admin_roles').select('user_id');
    
    const nonPassengerIds = new Set([
      ...(drivers?.map(d => d.user_id) || []),
      ...(admins?.map(a => a.user_id) || [])
    ]);

    const finalPassengers = (profiles || [])
      .filter(p => !nonPassengerIds.has(p.id))
      .map(p => ({
        id: p.id,
        fullName: p.full_name || '',
        email: p.email || '',
        mobile: p.mobile || '',
        emailVerified: p.email_verified || false,
        status: p.account_status || 'active',
        address: p.address || '',
        createdAt: p.created_at,
        updatedAt: p.updated_at,
        roles: ['passenger']
      }))
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    return new Response(JSON.stringify(finalPassengers), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Request failed.' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

