/**
 * Retired signup endpoint.
 *
 * Passenger and driver registration now use Supabase Auth signUp directly
 * from the authenticated Flutter flows. Signup and driver-application
 * email OTP are intentionally not supported here.
 *
 * Keep this handler non-functional until any deployed copy is removed
 * separately through the Supabase dashboard or CLI.
 */
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return new Response(JSON.stringify({
    code: 'signup_flow_retired',
    message: 'Use Supabase Auth email/password signup.',
  }), {
    status: 410,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
