import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const ACCOUNTS = [
  { name: 'ganaparthimanishchowdary@gmail.com', oldId: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23', activeId: 'cea15235-5af5-4c82-893f-c88d6ada8d20' },
  { name: 'ganaparthimanish@gmail.com', oldId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', activeId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' },
  { name: 'ecomartx1@gmail.com', oldId: '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07', activeId: '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07' }
];

async function verifyAllLegacy() {
  console.log('====================================================');
  console.log('    FINAL RECONCILIATION & INTEGRITY VERIFICATION  ');
  console.log('====================================================\n');

  for (const acc of ACCOUNTS) {
    const { count: oldOrd } = await supabase.from('orders').select('*', { count: 'exact', head: true }).eq('traveller_id', acc.oldId);
    const { count: oldBkTrav } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('traveller_id', acc.oldId);
    const { count: oldBkAgent } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('agent_id', acc.oldId);

    const { count: actOrd } = await supabase.from('orders').select('*', { count: 'exact', head: true }).eq('traveller_id', acc.activeId);
    const { count: actBkTrav } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('traveller_id', acc.activeId);
    const { count: actBkAgent } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('agent_id', acc.activeId);

    console.log(`Account: ${acc.name}`);
    if (acc.oldId !== acc.activeId) {
      console.log(`  OLD ID (${acc.oldId}): orders=${oldOrd ?? 0}, bookings_traveller=${oldBkTrav ?? 0}, bookings_agent=${oldBkAgent ?? 0}`);
    }
    console.log(`  ACTIVE ID (${acc.activeId}): orders=${actOrd ?? 0}, bookings_traveller=${actBkTrav ?? 0}, bookings_agent=${actBkAgent ?? 0}\n`);
  }
}

verifyAllLegacy();
