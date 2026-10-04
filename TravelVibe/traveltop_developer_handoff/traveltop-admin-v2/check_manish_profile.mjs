import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkManish() {
  console.log('--- PROFILES ---');
  const { data: profiles, error: err1 } = await supabase
    .from('profiles')
    .select('*')
    .ilike('full_name', '%manish%');
  console.log('Profiles:', JSON.stringify(profiles, null, 2), err1);

  console.log('--- AGENT DETAILS ---');
  const { data: agents, error: err2 } = await supabase
    .from('agent_details')
    .select('*');
  console.log('Agent details count:', agents?.length, err2);
  if (agents) {
    for (const a of agents) {
      console.log('Agent:', a.id, a.full_name, a.photo_url, a.selfie_url);
    }
  }
}

checkManish();
