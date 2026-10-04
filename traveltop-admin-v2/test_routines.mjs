import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function check() {
  const { data: auth, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  console.log('Auth:', authErr ? authErr.message : auth.user.email);

  const { data, error } = await supabase.from('information_schema.routines').select('routine_name').eq('routine_schema', 'public');
  console.log('Routines error:', error?.message);
  console.log('Routines data:', data);
}

check();
