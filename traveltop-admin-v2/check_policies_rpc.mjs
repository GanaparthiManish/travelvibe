import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkPolicies() {
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  console.log('Logged in as:', authData?.user?.email);

  const tables = ['bookings','orders','wishlists','profiles','agent_details','messages','notifications','reviews','payouts'];

  for (const t of tables) {
    const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    const { data: anonData, error: anonErr } = await anonClient.from(t).select('*').limit(1);
    console.log(`Table '${t}' ANON SELECT: ${anonErr ? `DENIED (${anonErr.message})` : `ALLOWED (count: ${anonData?.length})`}`);
  }
}

checkPolicies();
