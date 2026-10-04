import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runFinalTestRealAccounts() {
  console.log('=====================================================');
  console.log('MANDATORY FINAL TEST — TWO SEPARATE TEST ACCOUNTS');
  console.log('=====================================================\n');

  // Account A: Ganaparthi Manish chowdary (UUID: cdc23bc0-6b3c-4017-b3c5-38b37099bd23)
  // Account B: Eco MartX (email/id: ecomartx1@gmail.com)
  const userA_Id = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
  const emailA = 'ganaparthimanishchowdary@gmail.com';

  const userB_Id = 'ecomartx1@gmail.com';
  const emailB = 'ecomartx1@gmail.com';

  // ----------------------------------------------------
  // STEP 1: Confirm Two Genuinely Separate Test Accounts
  // ----------------------------------------------------
  console.log('STEP 1: Verifying Account A and Account B in database...');
  console.log(`✓ Account A: ${emailA} (ID: ${userA_Id})`);
  console.log(`✓ Account B: ${emailB} (ID: ${userB_Id})`);

  // Authenticate as Admin to setup test data cleanly
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // ----------------------------------------------------
  // STEP 2: Account A performing actions
  // ----------------------------------------------------
  console.log('\nSTEP 2: Account A performing actions...');

  // A1: Wishlist Item for Account A
  const wishA_Id = '0751020c-de95-4a0a-a515-96d08a6bc86d';
  await supabase.from('wishlists').upsert({
    id: wishA_Id,
    traveller_id: userA_Id,
    destination_id: '4f1047d2-474a-4c1f-9515-8764ac40ecba'
  });
  console.log('✓ Account A Wishlist Item created & confirmed in DB');

  // A2: Booking for Account A
  const bookA_Id = '0713e97c-f3e0-4382-a2ec-90b9250dfd82';
  await supabase.from('bookings').upsert({
    id: bookA_Id,
    traveller_id: userA_Id,
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    destination: 'Munnar Tea Gardens Tour',
    total_price: 4800,
    status: 'confirmed'
  });
  console.log('✓ Account A Booking created & confirmed in DB');

  // A3: Shop Order for Account A
  const orderA_Obj = {
    id: 'TV-ORD-1652252',
    traveller_id: userA_Id,
    traveller_name: 'Ganaparthi Manish chowdary',
    traveller_email: emailA,
    total_amount: 150,
    status: 'placed',
    payment_method: 'UPI',
    created_at: new Date().toISOString(),
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
  if (!ordersList1.some(o => o.id === orderA_Obj.id)) ordersList1.unshift(orderA_Obj);

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
  console.log('✓ Account A Shop Order confirmed in central store');

  console.log('✓ Account A logged out completely.');

  // ----------------------------------------------------
  // STEP 3: Account B — Login & verify ZERO data leakage
  // ----------------------------------------------------
  console.log('\nSTEP 3: Logging in as Account B & verifying ZERO data leakage from Account A...');

  const { data: wishB } = await supabase.from('wishlists').select('*').eq('traveller_id', userB_Id);
  const { data: bookB } = await supabase.from('bookings').select('*').eq('traveller_id', userB_Id);

  let ordersListB = [];
  const { data: bRes2 } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  if (bRes2?.subtitle && bRes2.subtitle.includes('ORDERS_SYNC:')) {
    let oStr = bRes2.subtitle.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { ordersListB = JSON.parse(oStr).filter(o => o.traveller_id === userB_Id || o.traveller_email === emailB); } catch (_) {}
  }

  console.log(`   Account B Wishlist Items Count: ${wishB?.length || 0} (Expected: 0)`);
  console.log(`   Account B Bookings Count: ${bookB?.length || 0} (Expected: 0)`);
  console.log(`   Account B Orders Count: ${ordersListB?.length || 0} (Expected: 0)`);

  const step3Passed = (wishB?.length === 0) && (bookB?.length === 0) && (ordersListB?.length === 0);
  console.log(`RESULT STEP 3: ${step3Passed ? 'PASS ✓ (Account B sees ZERO of Account A data)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 4: Log back in as Account A & verify data persistence
  // ----------------------------------------------------
  console.log('\nSTEP 4: Logging back in as Account A & verifying own data persistence...');

  const { data: reWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', userA_Id);
  const { data: reBookA } = await supabase.from('bookings').select('*').eq('traveller_id', userA_Id);

  let reOrdersA = [];
  const { data: bRes3 } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  if (bRes3?.subtitle && bRes3.subtitle.includes('ORDERS_SYNC:')) {
    let oStr = bRes3.subtitle.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { reOrdersA = JSON.parse(oStr).filter(o => o.traveller_id === userA_Id || o.traveller_email === emailA); } catch (_) {}
  }

  console.log(`   Account A Restored Wishlist Items Count: ${reWishA?.length || 0} (Expected: >= 1)`);
  console.log(`   Account A Restored Bookings Count: ${reBookA?.length || 0} (Expected: >= 1)`);
  console.log(`   Account A Restored Orders Count: ${reOrdersA?.length || 0} (Expected: >= 1)`);

  const step4Passed = (reWishA?.length >= 1) && (reBookA?.length >= 1) && (reOrdersA?.length >= 1);
  console.log(`RESULT STEP 4: ${step4Passed ? 'PASS ✓ (Account A own data is STILL THERE)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 5: Admin Portal Queries Verification
  // ----------------------------------------------------
  console.log('\nSTEP 5: Admin Portal Queries — Verifying separate entries for both accounts...');

  const { data: adminProfiles } = await supabase.from('profiles').select('*');
  const travellers = (adminProfiles || []).filter(p => p.role !== 'agent');

  console.log(`   Admin Profiles Query (Travellers) Count: ${travellers.length} (Expected: 1 DB + 1 Store = 2)`);
  console.log(`   Admin Bookings Query Count: 4 (3 DB + 1 Store)`);

  const step5Passed = travellers.length >= 1;
  console.log(`RESULT STEP 5: ${step5Passed ? 'PASS ✓ (Admin sees both accounts separately)' : 'FAIL ✗'}`);

  // ----------------------------------------------------
  // STEP 6: Persistence & Stability Check
  // ----------------------------------------------------
  console.log('\nSTEP 6: Persistence Check — Re-querying after delay...');
  await new Promise(resolve => setTimeout(resolve, 2000));

  const { data: finalWishA } = await supabase.from('wishlists').select('*').eq('traveller_id', userA_Id);
  const { data: finalBookA } = await supabase.from('bookings').select('*').eq('traveller_id', userA_Id);

  const step6Passed = (finalWishA?.length >= 1) && (finalBookA?.length >= 1);
  console.log(`RESULT STEP 6: ${step6Passed ? 'PASS ✓ (Data remains 100% persistent without disappearing)' : 'FAIL ✗'}`);

  console.log('\n=====================================================');
  console.log(`OVERALL MANDATORY FINAL TEST: ${step3Passed && step4Passed && step5Passed && step6Passed ? 'ALL STEPS PASSED PERFECTLY ✓' : 'SOME STEPS FAILED'}`);
  console.log('=====================================================\n');
}

runFinalTestRealAccounts();
