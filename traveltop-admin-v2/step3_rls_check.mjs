import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runStep3RlsCheck() {
  console.log('=== STEP 3 — RLS POLICIES AUDIT REPORT ===\n');

  // Authenticate as admin user to test policy queries
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  console.log(`Authenticated Admin Session: ${authData.user.email} (${authData.user.id})\n`);

  const tables = ['bookings', 'orders', 'wishlists', 'profiles', 'agent_details'];

  for (const t of tables) {
    try {
      const { data, count, error } = await supabase.from(t).select('*', { count: 'exact' });
      console.log(`Table '${t}': Select count = ${count ?? data?.length}, Error = ${error ? JSON.stringify(error) : 'None (SELECT allowed)'}`);
    } catch (e) {
      console.error(`Table '${t}' query failed:`, e);
    }
  }
}

runStep3RlsCheck();
