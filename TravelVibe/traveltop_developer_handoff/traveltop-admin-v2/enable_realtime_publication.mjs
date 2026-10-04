import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function enableRealtimePublication() {
  console.log('=== ENABLING REALTIME PUBLICATION FOR TABLES ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Test inserting into orders table directly to verify orders postgres_changes
  console.log('Inserting test order into orders table to test orders Realtime...');
  const { data: testOrd, error: ordErr } = await supabase.from('orders').insert({
    traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    total_amount: 1,
    status: 'placed'
  }).select().single();

  console.log('Test Order Insert Result:', testOrd, ordErr ? `Error: ${JSON.stringify(ordErr)}` : 'Success ✓');

  if (testOrd?.id) {
    await supabase.from('orders').delete().eq('id', testOrd.id);
  }
}

enableRealtimePublication();
