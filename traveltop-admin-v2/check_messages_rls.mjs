import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAgentAuth() {
  const { data: authA, error: errA } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanishchowdary@gmail.com',
    password: 'Ganaparthi@123',
  });
  console.log('Agent Auth Result:', authA?.user?.id, 'Error:', errA?.message);

  const { data: profiles, error: pErr } = await supabase.from('profiles').select('*').eq('role', 'agent');
  console.log('Agents in profiles table:', profiles);
}

testAgentAuth();
