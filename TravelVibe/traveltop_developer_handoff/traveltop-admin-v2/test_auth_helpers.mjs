import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function getAuthenticatedClient(email, password, role = 'traveller') {
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  let { data: auth, error } = await client.auth.signInWithPassword({ email, password });
  
  if (error || !auth?.user) {
    console.log(`SignIn notice for ${email}: ${error?.message || 'No user'}. Attempting SignUp...`);
    const { data: signUpData, error: signUpErr } = await client.auth.signUp({
      email,
      password,
      options: { data: { full_name: role === 'agent' ? 'Real Live Agent' : 'Real Live Traveller' } }
    });
    auth = signUpData;
    if (signUpErr) console.log(`SignUp notice for ${email}: ${signUpErr.message}`);
  }

  const userId = auth?.user?.id;
  console.log(`Authenticated ${email} -> UID: ${userId}`);

  if (userId) {
    // Ensure profiles & agent_details table rows exist for RLS policies
    await client.from('profiles').upsert({
      id: userId,
      email,
      full_name: role === 'agent' ? 'Real Live Agent' : 'Real Live Traveller',
      role
    });

    if (role === 'agent') {
      await client.from('agent_details').upsert({
        id: userId,
        bio: 'Verified Test Agent',
        experience_years: 5,
        price_per_day: 2000,
        verification_status: 'approved'
      });
    }
  }

  return { client, userId };
}

async function runTest() {
  const traveller = await getAuthenticatedClient('real_traveller_test@travelvibe.com', 'TravelerPassword123!', 'traveller');
  const agent = await getAuthenticatedClient('real_agent_test@travelvibe.com', 'AgentPassword123!', 'agent');

  console.log('Traveller Client Ready:', traveller.userId);
  console.log('Agent Client Ready:', agent.userId);
}

runTest();
