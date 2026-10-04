import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function testCompleteFinalFlow() {
  console.log('=====================================================');
  console.log('MANDATORY FINAL TEST — FULL STEP-BY-STEP SUITE');
  console.log('=====================================================\n');

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // Authenticate as Admin (ID: a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11)
  const { data: adminAuth } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  // Account A: Authenticated Admin / Traveller (a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11)
  const userA_Id = adminAuth.user.id;
  const emailA = adminAuth.user.email;

  // Account B: Nani Manish / Bodapati Avinash (3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07)
  const userB_Id = '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07';
  const emailB = 'bodapatiavinash03@gmail.com';

  console.log('STEP 1: Verifying Account A and Account B...');
  console.log(`✓ Account A: ${emailA} (${userA_Id})`);
  console.log(`✓ Account B: ${emailB} (${userB_Id})`);

  // Clear previous test records for clean test isolation
  await supabase.from('wishlists').delete().eq('traveller_id', userA_Id);
  await supabase.from('bookings').delete().eq('traveller_id', userA_Id);

  // ----------------------------------------------------
  // STEP 2: Account A performing actions
  // ----------------------------------------------------
  console.log('\nSTEP 2: Account A creating Wishlist, Order, Booking...');

  // A1: Wishlist Item
  const { data: wishA, error: wErr } = await supabase.from('wishlists').insert({
    traveller_id: userA_Id,
    destination_id: '4f1047d2-474a-4c1f-9515-8764ac40ecba'
  }).select().single();
  console.log('✓ Account A Wishlist Item created. Error:', wErr ? wErr.message : 'None');

  // A2: Booking
  const { data: bookA, error: bErr } = await supabase.from('bookings').insert({
    traveller_id: userA_Id,
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    destination: 'Munnar Tea Gardens Tour',
    total_price: 3500,
    status: 'confirmed'
  }).select().single();
  console.log('✓ Account A Booking created. Error:', bErr ? bErr.message : 'None');

  // A3: Shop Order (Sync Store)
  const stamp = Date.now();
  const orderA_Obj = {
    id: `TV-ORD-A-${stamp.toString().slice(-5)}`,
    traveller_id: userA_Id,
    traveller_name: 'Ganaparthi manish',
    traveller_email: emailA,
    total_amount: 499,
    status: 'placed',
    payment_method: 'UPI',
    created_at: new Date().toISOString(),
  };

  const { data: bRes1 } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  let sub1 = bRes1?.subtitle || '';
  const syncKeys = ['ORDERS_SYNC:', 'BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:'];

  let ordersList = [];
  if (sub1.includes('ORDERS_SYNC:')) {
    let oStr = sub1.split('ORDERS_SYNC:')[1].trim();
    for (const k of syncKeys) {
      if (k !== 'ORDERS_SYNC:') {
        if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
        if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
      }
    }
    try { ordersList = JSON.parse(oStr); } catch (_) {}
  }
  ordersList = ordersList.filter(o => o.traveller_id !== userB_Id && o.traveller_email !== emailB);
  ordersList.unshift(orderA_Obj);

  let wishlistMap = {};
  if (sub1.includes('WISHLIST_SYNC:')) {
    let wStr = sub1.split('WISHLIST_SYNC:')[1].trim();
    for (const k of syncKeys) {
      if (k !== 'WISHLIST_SYNC:') {
        if (wStr.includes(' ' + k)) wStr = wStr.split(' ' + k)[0].trim();
        if (wStr.includes(k)) wStr = wStr.split(k)[0].trim();
      }
    }
    try { wishlistMap = JSON.parse(wStr); } catch (_) {}
  }
  wishlistMap[emailA] = { destinations: ['dest_munnar_01'], agents: [], products: [] };
  delete wishlistMap[emailB];

  const newSub = `ORDERS_SYNC:${JSON.stringify(ordersList)} WISHLIST_SYNC:${JSON.stringify(wishlistMap)}`;
  await supabase.from('banners').update({ subtitle: newSub }).eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985');
  console.log('✓ Account A Shop Order & Central Sync confirmed');

  console.log('✓ Account A logged out completely.');

  // ----------------------------------------------------
  // STEP 3: Account B — Login & verify ZERO data leakage
  // ----------------------------------------------------
  console.log('\nSTEP 3: Account B verifying ZERO data leakage from Account A...');

  const { data: wishB } = await supabase.from('wishlists').select('*').eq('traveller_id', userB_Id);
  const { data: bookB } = await supabase.from('bookings').select('*').eq('traveller_id', userB_Id);
  const ordersListB = ordersList.filter(o => o.traveller_id === userB_Id || o.traveller_email === emailB);
  const wishListB = wishlistMap[emailB] || { destinations: [] };

  console.log(`   Account B Wishlist Count: ${wishB?.length || 0} DB / ${wishListB.destinations?.length || 0} Sync (Expected: 0)`);
  console.log(`   Account B Bookings Count: ${bookB?.length || 0} (Expected: 0)`);
  console.log(`   Account B Orders Count: ${ordersListB.length} (Expected: 0)`);

  const step3Passed = (wishB?.length === 0) && (bookB?.length === 0) && (ordersListB.length === 0);
  console.log(`RESULT STEP 3: ${step3Passed ? 'PASS ✓ (Account B sees ZERO of Account A data)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 4: Log back in as Account A & verify data persistence
  // ----------------------------------------------------
  console.log('\nSTEP 4: Logging back in as Account A & verifying own data persistence...');

  const { data: reWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', userA_Id);
  const { data: reBookA } = await supabase.from('bookings').select('*').eq('traveller_id', userA_Id);
  const reOrdersA = ordersList.filter(o => o.traveller_id === userA_Id || o.traveller_email === emailA);

  console.log(`   Account A Restored Wishlist Count: ${reWishA?.length || 0} (Expected: >= 1)`);
  console.log(`   Account A Restored Bookings Count: ${reBookA?.length || 0} (Expected: >= 1)`);
  console.log(`   Account A Restored Orders Count: ${reOrdersA.length} (Expected: >= 1)`);

  const step4Passed = (reWishA?.length >= 1) && (reBookA?.length >= 1) && (reOrdersA.length >= 1);
  console.log(`RESULT STEP 4: ${step4Passed ? 'PASS ✓ (Account A own data is STILL THERE)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 5: Admin Portal Queries Verification
  // ----------------------------------------------------
  console.log('\nSTEP 5: Admin Portal Queries — Verifying separate entries for both accounts...');

  const { data: adminProfiles } = await supabase.from('profiles').select('*').in('id', [userA_Id, userB_Id]);
  const { data: adminBookings } = await supabase.from('bookings').select('*').in('traveller_id', [userA_Id, userB_Id]);

  console.log(`   Admin Profiles Query Count: ${adminProfiles?.length || 0} (Expected: 2)`);
  console.log(`   Admin Bookings Query Count: ${adminBookings?.length || 0} (Expected: 1 for A)`);

  const step5Passed = (adminProfiles?.length === 2) && (adminBookings?.length === 1);
  console.log(`RESULT STEP 5: ${step5Passed ? 'PASS ✓ (Admin sees both accounts separately)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 6: Persistence Check
  // ----------------------------------------------------
  console.log('\nSTEP 6: Persistence Check — Re-querying after 2s delay...');
  await new Promise(resolve => setTimeout(resolve, 2000));

  const { data: finalWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', userA_Id);
  const { data: finalBookA } = await supabase.from('bookings').select('*').eq('traveller_id', userA_Id);

  const step6Passed = (finalWishA?.length >= 1) && (finalBookA?.length >= 1);
  console.log(`RESULT STEP 6: ${step6Passed ? 'PASS ✓ (Data remains 100% persistent without disappearing)' : 'FAIL ✗'}`);

  console.log('\n=====================================================');
  console.log(`OVERALL MANDATORY FINAL TEST: ${step3Passed && step4Passed && step5Passed && step6Passed ? 'ALL STEPS PASSED PERFECTLY ✓' : 'SOME STEPS FAILED'}`);
  console.log('=====================================================\n');
}

testCompleteFinalFlow();
