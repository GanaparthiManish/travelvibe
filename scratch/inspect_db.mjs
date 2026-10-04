import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function inspect() {
  console.log('--- INSPECTING SUPABASE DATABASE ---');
  
  const { data: agents, error: errAg } = await supabase
    .from('agent_details')
    .select('*, profiles(*)');
  console.log('AGENT DETAILS COUNT:', agents?.length, errAg || '');
  console.log('AGENTS:', JSON.stringify(agents, null, 2));

  const { data: dests, error: errDest } = await supabase
    .from('destinations')
    .select('*');
  console.log('DESTINATIONS COUNT:', dests?.length, errDest || '');
  console.log('DESTINATIONS:', JSON.stringify(dests, null, 2));

  const { data: tickets, error: errTick } = await supabase
    .from('support_tickets')
    .select('*');
  console.log('SUPPORT TICKETS COUNT:', tickets?.length, errTick || '');

  const { data: products, error: errProd } = await supabase
    .from('products')
    .select('*');
  console.log('PRODUCTS COUNT:', products?.length, errProd || '');
}

inspect();
