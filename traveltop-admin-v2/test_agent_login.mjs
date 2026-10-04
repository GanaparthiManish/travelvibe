import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAgentLogin() {
  const { data, error } = await client.auth.signInWithPassword({
    email: 'ganaparthinarasimha@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (error) {
    console.log('Agent Sign In Error:', error.message);
  } else {
    console.log('✅ Agent Sign In SUCCESS! User ID:', data.user.id, 'Email:', data.user.email);
  }
}

testAgentLogin();
