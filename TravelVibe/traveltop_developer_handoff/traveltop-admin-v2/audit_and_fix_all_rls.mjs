import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runRlsAudit() {
  console.log('=====================================================');
  console.log('   STEP 4 — RLS SECURITY AUDIT & POLICY CHECK       ');
  console.log('=====================================================\n');

  const tables = ['bookings','orders','wishlists','profiles','agent_details','messages','notifications','reviews','payouts'];

  // Test Anonymous Client
  console.log('--- 1. Testing Unauthenticated (Anonymous) SELECT Access ---');
  for (const t of tables) {
    const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data, error } = await anonClient.from(t).select('*').limit(1);
    if (error) {
      console.log(`Table '${t}': 🟢 SECURE - Access Denied (${error.message})`);
    } else {
      console.log(`Table '${t}': ⚠️ ACCESSIBLE (Rows returned: ${data?.length})`);
    }
  }

  // Test Authenticated Admin Client
  console.log('\n--- 2. Testing Authenticated Admin Session Access ---');
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Admin authentication failed:', authErr.message);
  } else {
    console.log(`Authenticated as Admin: ${authData.user.email} (${authData.user.id})`);
    for (const t of tables) {
      const { data, count, error } = await supabase.from(t).select('*', { count: 'exact' });
      console.log(`Table '${t}': Admin SELECT status = ${error ? `ERROR (${error.message})` : `ALLOWED (Count: ${count ?? data?.length})`}`);
    }
  }
}

runRlsAudit();
