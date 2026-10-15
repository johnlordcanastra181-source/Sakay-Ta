import path from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { outputDir, readJson, requireEnv, writeJson } from './common.mjs';

const client = createClient(requireEnv('SUPABASE_URL'), requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
  auth: { persistSession: false, autoRefreshToken: false },
});
const firebase = await readJson(path.join(outputDir(), 'firebase-counts.json'));
const mappings = {
  users: 'profiles', admins: 'admin_roles', drivers: 'drivers', passengers: 'passenger_profiles',
  rides: 'rides', bookings: 'bookings', chat_messages: 'chat_messages', toda: 'todas',
  transactions: 'wallet_transactions', ratings: 'ratings', payments: 'payments',
  driver_earnings: 'driver_earnings', withdrawals: 'withdrawals', toda_associations: 'toda_associations',
  fare_matrix: 'fare_config', notifications: 'notifications', reports: 'reports',
};
const result = { checked_at: new Date().toISOString(), counts: {}, mismatches: [] };
for (const [source, table] of Object.entries(mappings)) {
  const { count, error } = await client.from(table).select('*', { count: 'exact', head: true });
  if (error) throw new Error(`${table}: ${error.message}`);
  result.counts[source] = { firebase: firebase[source] || 0, supabase_table: table, supabase: count || 0 };
  if ((firebase[source] || 0) !== (count || 0)) result.mismatches.push(result.counts[source]);
}
const { count: presenceCount, error: presenceError } = await client.from('driver_presence').select('*', { count: 'exact', head: true });
if (presenceError) throw new Error(`driver_presence: ${presenceError.message}`);
result.counts.driver_presence = { firebase: firebase.drivers || 0, supabase_table: 'driver_presence', supabase: presenceCount || 0 };
if ((firebase.drivers || 0) !== (presenceCount || 0)) result.mismatches.push(result.counts.driver_presence);
await writeJson(path.join(outputDir(), 'validation-report.json'), result);
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (result.mismatches.length) process.exitCode = 2;
