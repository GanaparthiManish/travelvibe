import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function setEcoMartxRole() {
  console.log('=== SETTING ECOMARTX ROLE TO TRAVELLER ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const { data, error } = await supabase.from('profiles')
    .update({ role: 'traveller', full_name: 'Eco MartX' })
    .eq('email', 'ecomartx1@gmail.com')
    .select();

  console.log('Update Eco MartX role result:', data, error ? `Error: ${JSON.stringify(error)}` : 'SUCCESS ✓');
}

setEcoMartxRole();
