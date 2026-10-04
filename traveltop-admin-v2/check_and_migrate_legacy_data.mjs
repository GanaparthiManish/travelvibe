import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const oldId = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
const newId = 'cea15235-5af5-4c82-893f-c88d6ada8d20';

async function migrateFullAgentDetails() {
  console.log('--- REPLICATING AGENT_DETAILS & MIGRATING 19 BOOKINGS ---');

  // 1. Fetch old agent_details row
  const { data: oldAd } = await supabase.from('agent_details').select('*').eq('id', oldId).maybeSingle();
  if (oldAd) {
    const newAd = {
      ...oldAd,
      id: newId
    };
    const { error: adErr } = await supabase.from('agent_details').upsert(newAd);
    if (adErr) console.error('Agent details upsert error:', adErr);
    else console.log('1. Replicated agent_details row to new ID:', newId);
  }

  // 2. Migrate bookings agent_id from oldId -> newId
  const { data: migratedBookings, error: bErr } = await supabase
    .from('bookings')
    .update({ agent_id: newId })
    .eq('agent_id', oldId)
    .select();

  if (bErr) {
    console.error('Bookings migration error:', bErr);
  } else {
    console.log(`2. Successfully migrated ${migratedBookings ? migratedBookings.length : 0} agent bookings from ${oldId} -> ${newId}!`);
  }

  // 3. Final verification counts
  const { count: oldOrders } = await supabase.from('orders').select('*', { count: 'exact', head: true }).eq('traveller_id', oldId);
  const { count: oldTravBookings } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('traveller_id', oldId);
  const { count: oldAgentBookings } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('agent_id', oldId);

  const { count: newOrders } = await supabase.from('orders').select('*', { count: 'exact', head: true }).eq('traveller_id', newId);
  const { count: newTravBookings } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('traveller_id', newId);
  const { count: newAgentBookings } = await supabase.from('bookings').select('*', { count: 'exact', head: true }).eq('agent_id', newId);

  console.log('\n====================================================');
  console.log('       FINAL VERIFICATION ROW COUNTS REPORT         ');
  console.log('====================================================');
  console.log(`OLD LEGACY ID (${oldId}):`);
  console.log(`  - orders (traveller_id = oldId): ${oldOrders ?? 0}`);
  console.log(`  - bookings (traveller_id = oldId): ${oldTravBookings ?? 0}`);
  console.log(`  - bookings (agent_id = oldId): ${oldAgentBookings ?? 0}`);

  console.log(`\nRECONCILIATION ID (${newId}):`);
  console.log(`  - orders (traveller_id = newId): ${newOrders ?? 0}`);
  console.log(`  - bookings (traveller_id = newId): ${newTravBookings ?? 0}`);
  console.log(`  - bookings (agent_id = newId): ${newAgentBookings ?? 0}`);
  console.log('====================================================');
}

migrateFullAgentDetails();
