import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function confirmEmailInDB() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // We can update the user profile status and run rpc or check auth
  console.log('Attempting to check profile for ganaparthinarasimha@gmail.com');
  const { data: p, error: pErr } = await supabase
    .from('profiles')
    .select('id, full_name, email, role')
    .eq('email', 'ganaparthinarasimha@gmail.com');

  console.log('Profile:', p, pErr);
}

confirmEmailInDB();
