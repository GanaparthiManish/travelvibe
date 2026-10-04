import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function fetchPgPolicies() {
  console.log('========================================================================');
  console.log(' FETCHING PG_POLICIES FROM SUPABASE FOR TARGET TABLES');
  console.log('========================================================================\n');

  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  console.log('Admin Authenticated:', authData?.user?.email);

  const targetTables = ['bookings','orders','wishlists','profiles','agent_details','messages','notifications','reviews','payouts'];

  // Try querying pg_policies via RPC or REST
  try {
    const { data: policies, error } = await supabase
      .from('pg_policies')
      .select('tablename, policyname, cmd, qual, with_check')
      .in('tablename', targetTables);

    if (error) {
      console.log('Direct pg_policies query notice:', error.message);
    } else {
      console.table(policies);
    }
  } catch (e) {
    console.error('Error fetching policies:', e);
  }
}

fetchPgPolicies();
