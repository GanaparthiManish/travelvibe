import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function fixMissingProfiles() {
  console.log('=== SYNCING PROFILES WITH AGENT DETAILS ===');
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Fetch all agent_details rows or auth users
  const { data: agentDetails } = await supabase.from('agent_details').select('id');
  console.log('Agent details rows count:', agentDetails?.length);

  // Fetch profiles
  const { data: profiles } = await supabase.from('profiles').select('id');
  const profileIds = new Set((profiles || []).map(p => p.id));
  console.log('Existing profile IDs count:', profileIds.size);
}

fixMissingProfiles();
