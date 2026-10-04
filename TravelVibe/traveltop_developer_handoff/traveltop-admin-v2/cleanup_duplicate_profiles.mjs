import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function cleanup() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Keep cdc23bc0-6b3c-4017-b3c5-38b37099bd23 which has the documents and details
  const deleteIds = ['38249f73-9615-49b8-8b92-38341bad7aa4', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'];

  for (const id of deleteIds) {
    const { error: aErr } = await supabase.from('agent_details').delete().eq('id', id);
    const { error: pErr } = await supabase.from('profiles').delete().eq('id', id);
    console.log(`Deleted ${id}:`, aErr, pErr);
  }

  // Ensure cdc23bc0-6b3c-4017-b3c5-38b37099bd23 is approved and verified
  const { data: updated, error: uErr } = await supabase
    .from('agent_details')
    .update({ verification_status: 'approved', verified: true, suspended: false })
    .eq('id', 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23')
    .select();

  console.log('Updated main agent:', updated, uErr);
}

cleanup();
