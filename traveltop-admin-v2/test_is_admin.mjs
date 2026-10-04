import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testIsAdmin() {
  await client.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const { data: adminRow } = await client.from('admin_users').select('*').limit(5);
  console.log('admin_users rows:', adminRow);

  const { data: isAdmin } = await client.rpc('is_admin');
  console.log('is_admin RPC result:', isAdmin);
}

testIsAdmin();
