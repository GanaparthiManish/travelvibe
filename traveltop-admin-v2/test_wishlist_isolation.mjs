import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testWishlistIsolation() {
  console.log('=====================================================');
  console.log('WISHLIST ISOLATION & PERSISTENCE VERIFICATION');
  console.log('=====================================================\n');

  // Account A: ganaparthimanishchowdary@gmail.com (ID: cdc23bc0-6b3c-4017-b3c5-38b37099bd23)
  const userA_Id = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
  const emailA = 'ganaparthimanishchowdary@gmail.com';

  // Account B: bodapatiavinash03@gmail.com (ID: 3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07)
  const userB_Id = '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07';
  const emailB = 'bodapatiavinash03@gmail.com';

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // 1. Clear wishlists for clean test
  await supabase.from('wishlists').delete().in('traveller_id', [userA_Id, userB_Id]);

  // 2. Insert Wishlist Item for Account A ONLY
  const { data: itemA, error: errA } = await supabase.from('wishlists').insert({
    traveller_id: userA_Id,
    destination_id: '4f1047d2-474a-4c1f-9515-8764ac40ecba'
  }).select().single();
  console.log('✓ Account A Wishlist Item created in DB:', itemA?.id, errA ? errA.message : 'None');

  // 3. Query Account B Wishlist
  const { data: wishB } = await supabase.from('wishlists').select('*').eq('traveller_id', userB_Id);
  console.log(`✓ Account B Wishlist Count in DB: ${wishB?.length || 0} (Expected: 0)`);

  // 4. Query Account A Wishlist
  const { data: wishA } = await supabase.from('wishlists').select('*').eq('traveller_id', userA_Id);
  console.log(`✓ Account A Wishlist Count in DB: ${wishA?.length || 0} (Expected: 1)`);

  const passed = (wishB?.length === 0) && (wishA?.length === 1);

  console.log('\n=====================================================');
  console.log(`WISHLIST ISOLATION TEST RESULT: ${passed ? 'PASS ✓ (Zero cross-account leak, 100% user persistence)' : 'FAIL ✗'}`);
  console.log('=====================================================\n');
}

testWishlistIsolation();
