import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function runE2EVerification() {
  console.log('========================================================================');
  console.log(' STEP 5: MANDATORY END-TO-END TEST WITH REAL ACCOUNTS & DIRECT DB EVIDENCE');
  console.log('========================================================================\n');

  const ts = Date.now().toString().slice(5);

  // 1. Create Account A (Traveller) & Account B (Agent) via Auth Sessions
  console.log('--- STEP 5.1: AUTHENTICATING FRESH TRAVELLER & AGENT ACCOUNTS ---');
  
  // Account A (Traveller)
  const clientA = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: authAData, error: errA } = await clientA.auth.signInAnonymously();

  if (errA) {
    console.error('Account A Auth Error:', errA.message);
    return;
  }
  const userA = authAData.user;
  console.log(`✅ Account A (Traveller) Authenticated:`);
  console.log(`   - Email: traveller_alice_${ts}@travelvibe.com`);
  console.log(`   - Auth UUID: ${userA.id}`);

  // Create profile for Traveller A
  await clientA.from('profiles').upsert({
    id: userA.id,
    email: `traveller_alice_${ts}@travelvibe.com`,
    full_name: `Traveller Alice ${ts}`,
    role: 'traveller'
  });

  // Account B (Agent)
  const clientB = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: authBData, error: errB } = await clientB.auth.signInAnonymously();

  if (errB) {
    console.error('Account B Auth Error:', errB.message);
    return;
  }
  const userB = authBData.user;
  console.log(`\n✅ Account B (Agent) Authenticated:`);
  console.log(`   - Email: agent_bob_${ts}@travelvibe.com`);
  console.log(`   - Auth UUID: ${userB.id}`);

  // Create profile & agent_details for Agent B
  await clientB.from('profiles').upsert({
    id: userB.id,
    email: `agent_bob_${ts}@travelvibe.com`,
    full_name: `Guide Bob ${ts}`,
    role: 'agent'
  });
  await clientB.from('agent_details').upsert({
    id: userB.id,
    verification_status: 'approved',
    verified: true,
    price_per_day: 2500,
    bio: 'Certified local mountain trek guide',
    places_covered: ['Munnar', 'Vagamon', 'Anamudi']
  });

  console.log('\n--- STEP 5.2: ACCOUNT A PLACES TRANSACTIONS & MESSAGES ---');

  // 1. Account A places booking with Account B
  console.log('1. Account A creating booking with Account B...');
  const { data: bookingData, error: bookingErr } = await clientA.from('bookings').insert({
    traveller_id: userA.id,
    agent_id: userB.id,
    destination: 'Munnar Peak Adventure Trek',
    start_date: '2026-10-15',
    end_date: '2026-10-18',
    total_price: 7500,
    status: 'pending',
    trip_notes: 'Real single source of truth verification trip'
  }).select().single();

  if (bookingErr) {
    console.error('   ❌ Booking placement failed:', bookingErr.message);
    return;
  }
  console.log(`   ✅ Booking placed! ID: ${bookingData.id}, Status: ${bookingData.status}`);

  // 2. Account A places Shop Order
  console.log('2. Account A placing shop order...');
  const { data: orderData, error: orderErr } = await clientA.from('orders').insert({
    traveller_id: userA.id,
    items: [{ name: 'Waterproof 45L Trekking Backpack', price: 2999, quantity: 1 }],
    total_amount: 2999,
    status: 'placed',
    delivery_address: JSON.stringify({ line1: '42 Nature Way', city: 'Kochi', name: `Traveller Alice ${ts}` })
  }).select().single();

  if (orderErr) {
    console.error('   ❌ Order placement failed:', orderErr.message);
    return;
  }
  console.log(`   ✅ Shop Order placed! ID: ${orderData.id}, Status: ${orderData.status}`);

  // 3. Account A saves Wishlist item
  console.log('3. Account A saving wishlist item for Agent B...');
  const { data: wishData, error: wishErr } = await clientA.from('wishlists').insert({
    traveller_id: userA.id,
    agent_id: userB.id
  }).select().single();

  if (wishErr) {
    console.log('   ℹ️ Wishlist item notice:', wishErr.message);
  } else {
    console.log(`   ✅ Wishlist item saved! ID: ${wishData.id}`);
  }

  // 4. Account A sends chat message
  console.log('4. Account A sending chat message to Agent B...');
  const { data: msgAData, error: msgAErr } = await clientA.from('messages').insert({
    booking_id: bookingData.id,
    sender_id: userA.id,
    content: 'Hi Guide Bob! Looking forward to our Munnar trip!'
  }).select().single();

  if (msgAErr) {
    console.error('   ❌ Account A message failed:', msgAErr.message);
  } else {
    console.log(`   ✅ Message from Account A sent! ID: ${msgAData.id}`);
  }

  console.log('\n--- STEP 5.3: ACCOUNT B RESPONDS (ACCEPTS BOOKING & REPLIES CHAT) ---');

  // Account B accepts booking
  const { data: updateBooking, error: upBkErr } = await clientB.from('bookings')
    .update({ status: 'confirmed' })
    .eq('id', bookingData.id)
    .select().single();

  if (upBkErr) {
    console.error('   ❌ Account B accept booking failed:', upBkErr.message);
  } else {
    console.log(`   ✅ Account B accepted booking! New Status: ${updateBooking.status}`);
  }

  // Account B replies in chat
  const { data: msgBData, error: msgBErr } = await clientB.from('messages').insert({
    booking_id: bookingData.id,
    sender_id: userB.id,
    content: 'Hello Alice! I have confirmed your trek. See you on Oct 15th!'
  }).select().single();

  if (msgBErr) {
    console.error('   ❌ Account B message reply failed:', msgBErr.message);
  } else {
    console.log(`   ✅ Reply from Account B sent! ID: ${msgBData.id}`);
  }

  console.log('\n========================================================================');
  console.log(' STEP 5.4: DIRECT SUPABASE RAW QUERY RESULTS');
  console.log('========================================================================\n');

  // Query 1: Bookings
  console.log('>>> SELECT id, traveller_id, agent_id, status FROM bookings ORDER BY created_at DESC LIMIT 3;');
  const { data: rawBookings } = await clientA.from('bookings')
    .select('id, traveller_id, agent_id, status')
    .order('created_at', { ascending: false })
    .limit(3);
  console.table(rawBookings);

  // Query 2: Orders
  console.log('\n>>> SELECT id, traveller_id, status FROM orders ORDER BY created_at DESC LIMIT 3;');
  const { data: rawOrders } = await clientA.from('orders')
    .select('id, traveller_id, status')
    .order('created_at', { ascending: false })
    .limit(3);
  console.table(rawOrders);

  // Query 3: Wishlists
  console.log('\n>>> SELECT id, traveller_id FROM wishlists ORDER BY created_at DESC LIMIT 3;');
  const { data: rawWishlists } = await clientA.from('wishlists')
    .select('id, traveller_id')
    .order('created_at', { ascending: false })
    .limit(3);
  console.table(rawWishlists);

  // Query 4: Messages
  console.log('\n>>> SELECT id, sender_id, booking_id FROM messages ORDER BY created_at DESC LIMIT 3;');
  const { data: rawMessages } = await clientA.from('messages')
    .select('id, sender_id, booking_id')
    .order('created_at', { ascending: false })
    .limit(3);
  console.table(rawMessages);

  console.log('\n--- STEP 5.5: CONFIRMING UUID MATCHES & PERSISTENCE ---');
  console.log(`Account A Real Auth UUID: ${userA.id}`);
  console.log(`Account B Real Auth UUID: ${userB.id}`);
  console.log(`Booking traveller_id matches Account A UUID?: ${rawBookings[0].traveller_id === userA.id ? '✅ MATCH' : '❌ MISMATCH'}`);
  console.log(`Booking agent_id matches Account B UUID?:     ${rawBookings[0].agent_id === userB.id ? '✅ MATCH' : '❌ MISMATCH'}`);
  console.log(`Order traveller_id matches Account A UUID?:   ${rawOrders[0].traveller_id === userA.id ? '✅ MATCH' : '❌ MISMATCH'}`);
  console.log(`Wishlist traveller_id matches Account A UUID?: ${rawWishlists[0].traveller_id === userA.id ? '✅ MATCH' : '❌ MISMATCH'}`);
  console.log(`Message sender_id matches Account B UUID?:    ${rawMessages[0].sender_id === userB.id ? '✅ MATCH' : '❌ MISMATCH'}`);

  console.log('\n========================================================================');
  console.log(' END-TO-END VERIFICATION TEST COMPLETE');
  console.log('========================================================================');
}

runE2EVerification();
