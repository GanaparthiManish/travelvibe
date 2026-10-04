import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function check() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  console.log('--- PROFILES ---');
  const { data: profiles, error: pErr } = await supabase.from('profiles').select('*');
  console.log(JSON.stringify(profiles, null, 2), pErr);

  console.log('--- AGENT DETAILS ---');
  const { data: agents, error: aErr } = await supabase.from('agent_details').select('*');
  console.log(JSON.stringify(agents, null, 2), aErr);

  console.log('--- AGENT GALLERY ---');
  const { data: gallery, error: gErr } = await supabase.from('agent_gallery').select('*');
  console.log(JSON.stringify(gallery, null, 2), gErr);
}

check();
