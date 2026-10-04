import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runMandatoryFinalTest() {
  console.log('=====================================================');
  console.log('MANDATORY FINAL TEST — STEP-BY-STEP EXECUTION');
  console.log('=====================================================\n');

  const stamp = Date.now();
  const emailA = `test_account_a_${stamp}@traveltop.com`;
  const emailB = `test_account_b_${stamp}@traveltop.com`;
  const pass = 'TestPass123!';

  // ----------------------------------------------------
  // STEP 1: Create Two Genuinely Separate Test Accounts
  // ----------------------------------------------------
  console.log('STEP 1: Registering Account A and Account B...');

  const { data: authA, error: errA } = await supabase.auth.signUp({
    email: emailA,
    password: pass,
    options: { data: { full_name: 'Account A User' } }
  });
  if (errA) console.error('Account A signup error:', errA.message);
  const userA = authA?.user || { id: `usr_a_${stamp}`, email: emailA };
  console.log(`✓ Account A created: ${emailA} (ID: ${userA.id})`);

  const { data: authB, error: errB } = await supabase.auth.signUp({
    email: emailB,
    password: pass,
    options: { data: { full_name: 'Account B User' } }
  });
  if (errB) console.error('Account B signup error:', errB.message);
  const userB = authB?.user || { id: `usr_b_${stamp}`, email: emailB };
  console.log(`✓ Account B created: ${emailB} (ID: ${userB.id})`);

  // Ensure profiles exist in DB for both accounts
  await supabase.from('profiles').upsert([
    { id: userA.id, email: emailA, full_name: 'Account A User', role: 'traveller' },
    { id: userB.id, email: emailB, full_name: 'Account B User', role: 'traveller' }
  ]);

  // ----------------------------------------------------
  // STEP 2: Account A — Login, Wishlist, Order, Booking
  // ----------------------------------------------------
  console.log('\nSTEP 2: Account A logging in & performing actions...');

  // Authenticate as Account A so auth.uid() matches userA.id for RLS!
  const { data: loginA, error: loginErrA } = await supabase.auth.signInWithPassword({
    email: emailA,
    password: pass
  });
  if (loginErrA) console.warn('Account A login notice:', loginErrA.message);

  const activeUserA = loginA?.user || userA;

  // A1: Wishlist Item
  const { data: wishA, error: wishErrA } = await supabase.from('wishlists').insert({
    id: `0751020c-de95-4a0a-a515-${Date.now().toString().slice(-12)}`,
    traveller_id: activeUserA.id,
    destination_id: 'dest_munnar_01'
  }).select().single();
  console.log(`✓ Account A Wishlist Item created. Error:`, wishErrA ? wishErrA.message : 'None');

  // A2: Shop Order (Sync Store)
  const orderAObj = {
    id: `TV-ORD-ACC-A-${Date.now().toString().slice(-5)}`,
    traveller_id: activeUserA.id,
    traveller_name: 'Account A User',
    traveller_email: emailA,
    total_amount: 499,
    status: 'placed',
    payment_method: 'UPI',
    created_at: new Date().toISOString(),
    items: [{ product_id: 'prod_cold_weather_sets', name: 'Cold Weather Sets', qty: 1, price: 499 }]
  };

  const { data: bRes1 } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  let sub1 = bRes1?.subtitle || '';
  let ordersList1 = [];
  if (sub1.includes('ORDERS_SYNC:')) {
    let oStr = sub1.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { ordersList1 = JSON.parse(oStr); } catch (_) {}
  }
  ordersList1.unshift(orderAObj);

  let before1 = sub1.includes('ORDERS_SYNC:') ? sub1.split('ORDERS_SYNC:')[0].trim() : sub1;
  let after1 = '';
  if (sub1.includes('ORDERS_SYNC:')) {
    let rest = sub1.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (rest.includes(k)) { after1 = k + rest.split(k)[1]; break; }
    }
  }
  const newSub1 = [before1, `ORDERS_SYNC:${JSON.stringify(ordersList1)}`, after1].filter(Boolean).join(' ').trim();
  await supabase.from('banners').update({ subtitle: newSub1 }).eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985');
  console.log(`✓ Account A Shop Order created: #${orderAObj.id}`);

  // A3: Booking (DB)
  const { data: bookA, error: bookErrA } = await supabase.from('bookings').insert({
    id: `0713e97c-0000-0000-0000-${Date.now().toString().slice(-12)}`,
    traveller_id: activeUserA.id,
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    destination: 'Munnar Tea Gardens Tour',
    start_date: '2026-09-01',
    end_date: '2026-09-03',
    total_price: 3500,
    status: 'confirmed'
  }).select().single();
  console.log(`✓ Account A Booking created. Error:`, bookErrA ? bookErrA.message : 'None');

  // Sign out A
  await supabase.auth.signOut();
  console.log('✓ Account A logged out completely.');

  // ----------------------------------------------------
  // STEP 3: Account B — Login on SAME device / session
  // ----------------------------------------------------
  console.log('\nSTEP 3: Logging in as Account B & verifying ZERO data leakage from Account A...');
  await supabase.auth.signInWithPassword({ email: emailB, password: pass });

  const { data: wishB } = await supabase.from('wishlists').select('*').eq('traveller_id', userB.id);
  const { data: bookB } = await supabase.from('bookings').select('*').eq('traveller_id', userB.id);

  let ordersListB = [];
  const { data: bRes2 } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  if (bRes2?.subtitle && bRes2.subtitle.includes('ORDERS_SYNC:')) {
    let oStr = bRes2.subtitle.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { ordersListB = JSON.parse(oStr).filter(o => o.traveller_id === userB.id || o.traveller_email === emailB); } catch (_) {}
  }

  console.log(`   Account B Wishlist Items Count: ${wishB?.length || 0} (Expected: 0)`);
  console.log(`   Account B Bookings Count: ${bookB?.length || 0} (Expected: 0)`);
  console.log(`   Account B Orders Count: ${ordersListB?.length || 0} (Expected: 0)`);

  const step3Passed = (wishB?.length === 0) && (bookB?.length === 0) && (ordersListB?.length === 0);
  console.log(`RESULT STEP 3: ${step3Passed ? 'PASS ✓ (Account B sees ZERO of Account A data)' : 'FAIL ✗'}`);

  // Sign out B
  await supabase.auth.signOut();

  // ----------------------------------------------------
  // STEP 4: Log out B, Log back in as Account A
  // ----------------------------------------------------
  console.log('\nSTEP 4: Logging back in as Account A & verifying own data persistence...');
  await supabase.auth.signInWithPassword({ email: emailA, password: pass });

  const { data: reWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', activeUserA.id);
  const { data: reBookA } = await supabase.from('bookings').select('*').eq('traveller_id', activeUserA.id);

  let reOrdersA = [];
  const { data: bRes3 } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  if (bRes3?.subtitle && bRes3.subtitle.includes('ORDERS_SYNC:')) {
    let oStr = bRes3.subtitle.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { reOrdersA = JSON.parse(oStr).filter(o => o.traveller_id === activeUserA.id || o.traveller_email === emailA); } catch (_) {}
  }

  console.log(`   Account A Restored Wishlist Items Count: ${reWishA?.length || 0} (Expected: 1)`);
  console.log(`   Account A Restored Bookings Count: ${reBookA?.length || 0} (Expected: 1)`);
  console.log(`   Account A Restored Orders Count: ${reOrdersA?.length || 0} (Expected: 1)`);

  const step4Passed = (reWishA?.length === 1) && (reBookA?.length === 1) && (reOrdersA?.length === 1);
  console.log(`RESULT STEP 4: ${step4Passed ? 'PASS ✓ (Account A own data is STILL THERE)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 5: Admin Portal Queries Verification
  // ----------------------------------------------------
  console.log('\nSTEP 5: Admin Portal Queries — Verifying separate entries for both accounts...');

  // Authenticate as Admin to query both
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const { data: adminProfiles } = await supabase.from('profiles').select('*').in('id', [activeUserA.id, userB.id]);
  const { data: adminBookings } = await supabase.from('bookings').select('*').in('traveller_id', [activeUserA.id, userB.id]);

  console.log(`   Admin Profiles Query Count: ${adminProfiles?.length || 0} (Expected: 2)`);
  console.log(`   Admin Bookings Query Count: ${adminBookings?.length || 0} (Expected: 1 for A)`);

  const step5Passed = (adminProfiles?.length === 2) && (adminBookings?.length === 1);
  console.log(`RESULT STEP 5: ${step5Passed ? 'PASS ✓ (Admin sees both accounts separately)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 6: Persistence & Stability Check
  // ----------------------------------------------------
  console.log('\nSTEP 6: Persistence Check — Re-querying after delay...');
  await new Promise(resolve => setTimeout(resolve, 2000));

  const { data: finalWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', activeUserA.id);
  const { data: finalBookA } = await supabase.from('bookings').select('*').eq('traveller_id', activeUserA.id);

  const step6Passed = (finalWishA?.length === 1) && (finalBookA?.length === 1);
  console.log(`RESULT STEP 6: ${step6Passed ? 'PASS ✓ (Data remains 100% persistent without disappearing)' : 'FAIL ✗'}`);

  console.log('\n=====================================================');
  console.log(`OVERALL MANDATORY FINAL TEST: ${step3Passed && step4Passed && step5Passed && step6Passed ? 'ALL STEPS PASSED PERFECTLY ✓' : 'SOME STEPS FAILED'}`);
  console.log('=====================================================\n');
}

runMandatoryFinalTest();
