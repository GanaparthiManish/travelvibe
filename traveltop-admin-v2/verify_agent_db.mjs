import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function check() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const { data: profiles, error: pErr } = await supabase
    .from('profiles')
    .select('*')
    .eq('email', 'ganaparthinarasimha@gmail.com');

  console.log('Profiles for email:', profiles, pErr);

  if (profiles && profiles.length > 0) {
    for (const p of profiles) {
      const { data: agentDetails, error: aErr } = await supabase
        .from('agent_details')
        .select('*')
        .eq('id', p.id);
      console.log(`Agent Details for ${p.id}:`, agentDetails, aErr);
    }
  }
}

check();
