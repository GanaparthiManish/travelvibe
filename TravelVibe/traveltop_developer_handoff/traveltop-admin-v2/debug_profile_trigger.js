import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function checkProfileTrigger() {
  console.log('=== CHECKING PROFILES & TRIGGER IN SUPABASE ===');
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Check profiles count and RLS
  const { data: profs, error: profErr } = await supabase.from('profiles').select('*').limit(5);
  console.log('Profiles sample:', profs, 'Error:', profErr);

  // Try inserting a dummy profile with anon key (should fail RLS if not authenticated)
  const testId = '00000000-0000-0000-0000-000000000099';
  const { error: insErr } = await supabase.from('profiles').insert({
    id: testId,
    full_name: 'Test Anon',
    email: 'testanon@test.com',
    role: 'agent'
  });
  console.log('Anon Profile Insert Error (Expected RLS):', insErr);
}

checkProfileTrigger();
