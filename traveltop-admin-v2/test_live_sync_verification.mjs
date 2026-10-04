import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testLiveSync() {
  console.log('=== REALTIME LIVE SYNC VERIFICATION TEST ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  let bookingReceived = false;
  let orderReceived = false;

  // 1. Subscribe to admin-bookings-changes
  const bSub = supabase.channel('admin-bookings-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, (payload) => {
      console.log('✓ ADMIN RECEIVED LIVE BOOKING EVENT:', payload.new?.id || payload);
      bookingReceived = true;
    })
    .subscribe((status) => console.log('Bookings Channel Subscription Status:', status));

  // 2. Subscribe to order_live_status_channel
  const oSub = supabase.channel('order_live_status_channel')
    .on('broadcast', { event: 'order_placed' }, (payload) => {
      console.log('✓ ADMIN RECEIVED LIVE ORDER BROADCAST:', payload.payload?.id || payload);
      orderReceived = true;
    })
    .subscribe((status) => console.log('Orders Channel Subscription Status:', status));

  await new Promise(r => setTimeout(r, 2500));

  // Simulate placing a new booking from Traveller App
  console.log('\n--- Simulating Traveller App creating new Booking ---');
  const { data: newBook } = await supabase.from('bookings').insert({
    traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    destination: 'Live Sync Test Trek',
    total_price: 2999,
    status: 'confirmed'
  }).select().single();

  // Simulate placing a new order from Traveller App
  console.log('--- Simulating Traveller App broadcasting new Order ---');
  const testOrderData = {
    id: `TV-ORD-LIVE-${Date.now().toString().slice(-4)}`,
    traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    traveller_name: 'Ganaparthi manish',
    total_amount: 299,
    status: 'placed',
    created_at: new Date().toISOString()
  };

  const senderCh = supabase.channel('order_live_status_channel');
  senderCh.subscribe(async (status) => {
    if (status === 'SUBSCRIBED') {
      await senderCh.send({ type: 'broadcast', event: 'order_placed', payload: testOrderData });
    }
  });

  await new Promise(r => setTimeout(r, 3000));

  console.log('\n=====================================================');
  console.log('LIVE SYNC TEST RESULT:');
  console.log('  - Booking Live Sync Received:', bookingReceived ? 'PASS ✓' : 'FAIL ✗');
  console.log('  - Order Live Sync Received:', orderReceived ? 'PASS ✓' : 'FAIL ✗');
  console.log('=====================================================\n');

  // Clean test booking
  if (newBook?.id) {
    await supabase.from('bookings').delete().eq('id', newBook.id);
  }

  supabase.removeChannel(bSub);
  supabase.removeChannel(oSub);
  supabase.removeChannel(senderCh);
}

testLiveSync();
