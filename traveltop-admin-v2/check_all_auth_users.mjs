import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function findConfirmedAccounts() {
  const { data: profiles } = await client.from('profiles').select('id, email, full_name, role');
  console.log('Total profiles:', profiles?.length);

  const passwords = ['Ganaparthi@123', 'Password123!', 'password123', '123456'];

  for (const p of profiles || []) {
    if (!p.email) continue;
    for (const pwd of passwords) {
      const { data, error } = await client.auth.signInWithPassword({ email: p.email, password: pwd });
      if (data?.user) {
        console.log(`✅ CONFIRMED ACTIVE AUTH ACCOUNT: Role: ${p.role} | Email: ${p.email} | Password: ${pwd} | UUID: ${data.user.id}`);
        break;
      }
    }
  }
}

findConfirmedAccounts();
