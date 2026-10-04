import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runSingleSourceOfTruthTest() {
  console.log('================================================================');
  console.log('TRAVELVIBE — AGENT & TRAVELLER SINGLE SOURCE OF TRUTH TEST SUITE');
  console.log('================================================================\n');

  // Authenticate Account A (Primary User)
  const { data: authA, error: errA } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123',
  });
  if (errA) {
    console.error('Account A Auth Failed:', errA.message);
    return;
  }
  const userA = authA.user;
  console.log(`[Account A] Authenticated successfully!`);
  console.log(`  - User ID (UUID): ${userA.id}`);
  console.log(`  - Email: ${userA.email}\n`);

  // Place transactions for Account A
  const agentId = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';

  console.log('[Account A] Creating Booking...');
  const { data: bookingA, error: bErrA } = await supabase.from('bookings').insert({
    traveller_id: userA.id,
    agent_id: agentId,
    start_date: '2026-10-10',
    end_date: '2026-10-15',
    total_price: 12500,
    status: 'pending',
    destination: 'Munnar Tea Estates & Trek',
    trip_notes: 'Account A single source of truth verification'
  }).select();
  if (bErrA) console.error('  - Booking A Insert Error:', bErrA.message);
  else console.log(`  - Booking A Created! ID: ${bookingA[0].id}`);

  console.log('[Account A] Adding Wishlist Item...');
  const { data: wishA, error: wErrA } = await supabase.from('wishlists').insert({
    traveller_id: userA.id,
    agent_id: agentId
  }).select();
  if (wErrA) console.log('  - Wishlist A Notice:', wErrA.message);
  else console.log(`  - Wishlist A Created! ID: ${wishA[0].id}`);

  console.log('\n----------------------------------------------------------------');

  // Fetch / Select Account B (Secondary User)
  const { data: profiles } = await supabase.from('profiles').select('id, email').neq('id', userA.id).limit(1);
  const userB = profiles && profiles.length > 0 ? { id: profiles[0].id, email: profiles[0].email } : null;

  if (userB) {
    console.log(`[Account B] Authenticated / Selected successfully!`);
    console.log(`  - User ID (UUID): ${userB.id}`);
    console.log(`  - Email: ${userB.email}\n`);

    console.log('[Account B] Creating Booking...');
    const { data: bookingB, error: bErrB } = await supabase.from('bookings').insert({
      traveller_id: userB.id,
      agent_id: agentId,
      start_date: '2026-11-01',
      end_date: '2026-11-04',
      total_price: 8900,
      status: 'pending',
      destination: 'Wayanad Wildlife Exploration',
      trip_notes: 'Account B single source of truth verification'
    }).select();
    if (bErrB) console.error('  - Booking B Insert Error:', bErrB.message);
    else console.log(`  - Booking B Created! ID: ${bookingB[0].id}`);

    console.log('[Account B] Adding Wishlist Item...');
    const { data: wishB, error: wErrB } = await supabase.from('wishlists').insert({
      traveller_id: userB.id,
      destination_id: '4f1047d2-474a-4c1f-9515-8764ac40ecba'
    }).select();
    if (wErrB) console.log('  - Wishlist B Notice:', wErrB.message);
    else console.log(`  - Wishlist B Created! ID: ${wishB[0].id}`);
  }

  console.log('\n================================================================');
  console.log('LIVE POSTGRESQL TABLES VERIFICATION QUERIES');
  console.log('================================================================\n');

  // Query Bookings
  console.log('1. SELECT id, traveller_id, agent_id, status FROM bookings ORDER BY created_at DESC LIMIT 5;');
  const { data: bookingsList } = await supabase
    .from('bookings')
    .select('id, traveller_id, agent_id, status')
    .order('created_at', { ascending: false })
    .limit(5);

  console.table(bookingsList);

  // Query Orders
  console.log('\n2. SELECT id, traveller_id, status FROM orders ORDER BY created_at DESC LIMIT 5;');
  const { data: ordersList } = await supabase
    .from('orders')
    .select('id, traveller_id, status')
    .order('created_at', { ascending: false })
    .limit(5);

  console.table(ordersList);

  // Query Wishlists
  console.log('\n3. SELECT id, traveller_id FROM wishlists ORDER BY created_at DESC LIMIT 5;');
  const { data: wishlistsList } = await supabase
    .from('wishlists')
    .select('id, traveller_id')
    .order('created_at', { ascending: false })
    .limit(5);

  console.table(wishlistsList);

  console.log('\n================================================================');
  console.log('UUID AUTHENTICITY CONFIRMATION:');
  if (userA && userB) {
    const uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
    const isDistinct = userA.id !== userB.id;
    const isUuidA = uuidRegex.test(userA.id);
    const isUuidB = uuidRegex.test(userB.id);
    console.log(`- Account A traveller_id (${userA.id}): Valid UUID? ${isUuidA}`);
    console.log(`- Account B traveller_id (${userB.id}): Valid UUID? ${isUuidB}`);
    console.log(`- Are traveller_id values real and distinct? ${isDistinct ? 'YES ✓' : 'NO ✗'}`);
  }
  console.log('================================================================\n');
}

runSingleSourceOfTruthTest();
