import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function listUsers() {
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  console.log('Admin login:', authData.user.email);

  const { data: travellers } = await supabase.from('profiles').select('id, email, full_name, role').eq('role', 'traveller').limit(5);
  const { data: agents } = await supabase.from('profiles').select('id, email, full_name, role').eq('role', 'agent').limit(5);

  console.log('Travellers in DB:', travellers);
  console.log('Agents in DB:', agents);
}

listUsers();
