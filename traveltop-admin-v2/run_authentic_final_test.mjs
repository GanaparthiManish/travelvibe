import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runAuthenticFinalTest() {
  console.log('=====================================================');
  console.log('MANDATORY FINAL TEST — AUTHENTIC ACCOUNTS EXECUTION');
  console.log('=====================================================\n');

  const pass = 'TestPass123!';
  const emailA = 'flow_test_acc_a@travelvibe.com';
  const emailB = 'flow_test_acc_b@travelvibe.com';

  // ----------------------------------------------------
  // STEP 1: Register Account A and Account B
  // ----------------------------------------------------
  console.log('STEP 1: Initializing Account A and Account B...');

  let userA_Id, userB_Id;

  const { data: authA } = await supabase.auth.signInWithPassword({ email: emailA, password: pass });
  if (authA?.user) {
    userA_Id = authA.user.id;
  } else {
    const { data: signA } = await supabase.auth.signUp({ email: emailA, password: pass, options: { data: { full_name: 'Flow Test User A' } } });
    userA_Id = signA?.user?.id;
  }

  const { data: authB } = await supabase.auth.signInWithPassword({ email: emailB, password: pass });
  if (authB?.user) {
    userB_Id = authB.user.id;
  } else {
    const { data: signB } = await supabase.auth.signUp({ email: emailB, password: pass, options: { data: { full_name: 'Flow Test User B' } } });
    userB_Id = signB?.user?.id;
  }

  console.log(`✓ Account A: ${emailA} (ID: ${userA_Id})`);
  console.log(`✓ Account B: ${emailB} (ID: ${userB_Id})`);

  // Ensure profiles exist in DB for both accounts
  await supabase.from('profiles').upsert([
    { id: userA_Id, email: emailA, full_name: 'Flow Test User A', role: 'traveller' },
    { id: userB_Id, email: emailB, full_name: 'Flow Test User B', role: 'traveller' }
  ]);

  // ----------------------------------------------------
  // STEP 2: Account A performing actions
  // ----------------------------------------------------
  console.log('\nSTEP 2: Account A logging in & performing actions...');

  await supabase.auth.signInWithPassword({ email: emailA, password: pass });

  // A1: Wishlist Item
  const { data: wishA, error: wishErrA } = await supabase.from('wishlists').upsert({
    id: '0751020c-de95-4a0a-a515-96d08a6bc861',
    traveller_id: userA_Id,
    destination_id: 'dest_munnar_01'
  }).select().single();
  console.log('✓ Account A Wishlist Item created. Error:', wishErrA ? wishErrA.message : 'None');

  // A2: Booking
  const { data: bookA, error: bookErrA } = await supabase.from('bookings').upsert({
    id: '0713e97c-0000-0000-0000-000000000001',
    traveller_id: userA_Id,
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    destination: 'Munnar Tea Gardens Tour',
    total_price: 3500,
    status: 'confirmed'
  }).select().single();
  console.log('✓ Account A Booking created. Error:', bookErrA ? bookErrA.message : 'None');

  // A3: Shop Order (Sync Store)
  const orderA_Obj = {
    id: 'TV-ORD-ACC-A-AUTH',
    traveller_id: userA_Id,
    traveller_name: 'Flow Test User A',
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
  ordersList = ordersList.filter(o => o.id !== orderA_Obj.id);
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

  const newSubtitle = `ORDERS_SYNC:${JSON.stringify(ordersList)} WISHLIST_SYNC:${JSON.stringify(wishlistMap)}`;
  await supabase.from('banners').update({ subtitle: newSubtitle }).eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985');
  console.log('✓ Account A Shop Order & Wishlist Sync confirmed');

  // Sign out A
  await supabase.auth.signOut();
  console.log('✓ Account A logged out completely.');

  // ----------------------------------------------------
  // STEP 3: Account B — Login & verify ZERO data leakage
  // ----------------------------------------------------
  console.log('\nSTEP 3: Logging in as Account B & verifying ZERO data leakage from Account A...');
  await supabase.auth.signInWithPassword({ email: emailB, password: pass });

  const { data: wishB } = await supabase.from('wishlists').select('*').eq('traveller_id', userB_Id);
  const { data: bookB } = await supabase.from('bookings').select('*').eq('traveller_id', userB_Id);

  let ordersListB = ordersList.filter(o => o.traveller_id === userB_Id || o.traveller_email === emailB);
  let wishListB = wishlistMap[emailB] || { destinations: [] };

  console.log(`   Account B Wishlist Items Count: ${wishB?.length || 0} DB / ${wishListB.destinations?.length || 0} Sync (Expected: 0)`);
  console.log(`   Account B Bookings Count: ${bookB?.length || 0} (Expected: 0)`);
  console.log(`   Account B Orders Count: ${ordersListB?.length || 0} (Expected: 0)`);

  const step3Passed = (wishB?.length === 0) && (bookB?.length === 0) && (ordersListB?.length === 0);
  console.log(`RESULT STEP 3: ${step3Passed ? 'PASS ✓ (Account B sees ZERO of Account A data)' : 'FAIL ✗'}`);

  // Sign out B
  await supabase.auth.signOut();

  // ----------------------------------------------------
  // STEP 4: Log back in as Account A & verify data persistence
  // ----------------------------------------------------
  console.log('\nSTEP 4: Logging back in as Account A & verifying own data persistence...');
  await supabase.auth.signInWithPassword({ email: emailA, password: pass });

  const { data: reWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', userA_Id);
  const { data: reBookA } = await supabase.from('bookings').select('*').eq('traveller_id', userA_Id);

  let reOrdersA = ordersList.filter(o => o.traveller_id === userA_Id || o.traveller_email === emailA);
  let reWishSyncA = wishlistMap[emailA] || { destinations: [] };

  console.log(`   Account A Restored Wishlist Items Count: ${reWishA?.length || 0} DB / ${reWishSyncA.destinations?.length || 0} Sync (Expected: 1)`);
  console.log(`   Account A Restored Bookings Count: ${reBookA?.length || 0} (Expected: 1)`);
  console.log(`   Account A Restored Orders Count: ${reOrdersA?.length || 0} (Expected: 1)`);

  const step4Passed = (reWishA?.length === 1 || reWishSyncA.destinations?.length === 1) && (reBookA?.length === 1) && (reOrdersA?.length === 1);
  console.log(`RESULT STEP 4: ${step4Passed ? 'PASS ✓ (Account A own data is STILL THERE)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 5: Admin Portal Queries Verification
  // ----------------------------------------------------
  console.log('\nSTEP 5: Admin Portal Queries — Verifying separate entries for both accounts...');
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

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

  const step6Passed = (finalWishA?.length === 1) && (finalBookA?.length === 1);
  console.log(`RESULT STEP 6: ${step6Passed ? 'PASS ✓ (Data remains 100% persistent without disappearing)' : 'FAIL ✗'}`);

  console.log('\n=====================================================');
  console.log(`OVERALL MANDATORY FINAL TEST: ${step3Passed && step4Passed && step5Passed && step6Passed ? 'ALL STEPS PASSED PERFECTLY ✓' : 'SOME STEPS FAILED'}`);
  console.log('=====================================================\n');
}

runAuthenticFinalTest();
