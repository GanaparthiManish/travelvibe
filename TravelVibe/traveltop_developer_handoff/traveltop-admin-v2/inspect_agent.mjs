import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function inspectAgent() {
  console.log('=== INSPECTING AGENTS IN DB ===');
  const { data: agents, error: aErr } = await supabase.from('agent_details').select('*, profiles(*)');
  console.log('Agent Details:', JSON.stringify(agents, null, 2));

  const { data: gallery, error: gErr } = await supabase.from('agent_gallery').select('*');
  console.log('Agent Gallery:', JSON.stringify(gallery, null, 2));
}

inspectAgent();
