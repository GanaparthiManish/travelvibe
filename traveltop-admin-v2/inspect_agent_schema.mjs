import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkAgents() {
  console.log('--- INSPECTING AGENT_DETAILS & PROFILES ---');
  const { data: agentDetails, error: err1 } = await supabase
    .from('agent_details')
    .select('*');
  
  console.log('agent_details error:', err1);
  console.log('agent_details count:', agentDetails?.length);
  if (agentDetails && agentDetails.length > 0) {
    console.log('Sample agent_details record keys:', Object.keys(agentDetails[0]));
    console.log('agent_details rows:', JSON.stringify(agentDetails, null, 2));
  }

  const { data: profiles, error: err2 } = await supabase
    .from('profiles')
    .select('*');
  console.log('profiles error:', err2);
  console.log('profiles total count:', profiles?.length);
  if (profiles && profiles.length > 0) {
    console.log('Sample profile record keys:', Object.keys(profiles[0]));
    console.log('profiles rows:', JSON.stringify(profiles, null, 2));
  }
}

checkAgents();
