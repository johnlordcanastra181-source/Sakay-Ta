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

    // 3. Perform queries concurrently. Revenue is derived from completed
    // rides and the fare stored on each ride; payment-provider rows are not
    // required for the current cash/driver-earnings workflow.
    const manilaOffsetMs = 8 * 60 * 60 * 1000;
    const manilaNow = new Date(Date.now() + manilaOffsetMs);
    const todayStart = new Date(
      Date.UTC(
        manilaNow.getUTCFullYear(),
        manilaNow.getUTCMonth(),
        manilaNow.getUTCDate(),
      ) - manilaOffsetMs,
    );
    const tomorrowStart = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000);
    const weekStart = new Date(todayStart.getTime() - 6 * 24 * 60 * 60 * 1000);

    const [
      { count: totalRides },
      { count: activeRides },
      { count: completedRides },
      { count: cancelledRides },
      { count: totalDrivers },
      { count: activeDrivers },
      { count: totalPassengers },
      { count: pendingDrivers },
      { count: pendingDriverApplications },
      { count: openReports },
      { data: completedRows, error: completedRowsError },
    ] = await Promise.all([
      adminClient.from('rides').select('*', { count: 'exact', head: true }),
      adminClient.from('rides').select('*', { count: 'exact', head: true }).in('status', ['searching', 'accepted', 'arrived', 'started']),
      adminClient.from('rides').select('*', { count: 'exact', head: true }).eq('status', 'completed').not('driver_id', 'is', null),
      adminClient.from('rides').select('*', { count: 'exact', head: true }).eq('status', 'cancelled'),
      adminClient.from('drivers').select('*', { count: 'exact', head: true }),
      adminClient.from('drivers').select('*', { count: 'exact', head: true }).in('application_status', ['approved', 'active']),
      adminClient.from('passenger_profiles').select('*', { count: 'exact', head: true }),
      adminClient.from('drivers').select('*', { count: 'exact', head: true }).eq('application_status', 'pending'),
      adminClient.from('driver_applications').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
      adminClient.from('reports').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
      adminClient.from('rides')
        .select('fare,driver_id,completed_at')
        .eq('status', 'completed')
        .not('driver_id', 'is', null)
        .gte('completed_at', weekStart.toISOString())
        .lt('completed_at', tomorrowStart.toISOString()),
    ]);

    if (completedRowsError) throw completedRowsError;
    const validCompletedRows = completedRows || [];
    const fareOf = (row: { fare?: unknown }) => Number(row.fare) || 0;
    const completedAtOf = (row: { completed_at?: unknown }) =>
      new Date(String(row.completed_at)).getTime();
    const revenueToday = validCompletedRows
      .filter((row) => {
        const completedAt = completedAtOf(row);
        return completedAt >= todayStart.getTime() &&
          completedAt < tomorrowStart.getTime();
      })
      .reduce((sum, row) => sum + fareOf(row), 0);
    const weeklyRevenue = Array.from({ length: 7 }, (_, index) => {
      const bucketStart = new Date(
        weekStart.getTime() + index * 24 * 60 * 60 * 1000,
      ).getTime();
      const bucketEnd = bucketStart + 24 * 60 * 60 * 1000;
      return validCompletedRows
        .filter((row) => {
          const completedAt = completedAtOf(row);
          return completedAt >= bucketStart && completedAt < bucketEnd;
        })
        .reduce((sum, row) => sum + fareOf(row), 0);
    });

    const responseData = {
      totalRides: totalRides || 0,
      activeRides: activeRides || 0,
      completedRides: completedRides || 0,
      cancelledRides: cancelledRides || 0,
      totalDrivers: totalDrivers || 0,
      activeDrivers: activeDrivers || 0,
      totalPassengers: totalPassengers || 0,
      pendingDrivers: (pendingDrivers || 0) + (pendingDriverApplications || 0),
      openReports: openReports || 0,
      revenueToday: revenueToday,
      weeklyRevenue: weeklyRevenue
    };

    return new Response(JSON.stringify(responseData), {
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

