import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function run() {
  console.log('Testing updating profiles suspended status...');
  const { data, error } = await supabase.from('profiles').update({ suspended: true }).eq('id', '8b77b7a1-9e51-4b4f-9d51-e2702fd8318e').select();
  console.log('Profiles update result:', data, 'Error:', error);

  console.log('Testing updating agent_details suspended status...');
  const { data: aData, error: aErr } = await supabase.from('agent_details').update({ suspended: true }).eq('id', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11').select();
  console.log('Agent details update result:', aData, 'Error:', aErr);
}

run();
