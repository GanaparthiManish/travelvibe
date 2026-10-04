import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runStep1Verification() {
  console.log('=== STEP 1 — DATABASE STATE VERIFICATION REPORT ===\n');

  // Authenticate as Admin user to bypass RLS for complete diagnostic read
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Admin Auth Error:', authErr);
  } else {
    console.log(`Authenticated Admin Session: ${authData.user.email} (ID: ${authData.user.id})\n`);
  }

  // 1. SELECT count(*) FROM public.bookings;
  const { count: countBookings, data: bookingsData, error: errB } = await supabase
    .from('bookings')
    .select('*', { count: 'exact' });
  console.log(`1. public.bookings count: ${countBookings ?? bookingsData?.length}`, errB ? `Error: ${JSON.stringify(errB)}` : '');
  if (bookingsData && bookingsData.length > 0) {
    bookingsData.forEach(b => console.log(`   - [Booking #${b.id}] Traveller: ${b.traveller_id} | Agent: ${b.agent_id} | Total: ₹${b.total_price} | Status: ${b.status}`));
  }

  // 2. SELECT count(*) FROM public.orders;
  const { count: countOrders, data: ordersData, error: errO } = await supabase
    .from('orders')
    .select('*', { count: 'exact' });
  console.log(`\n2. public.orders count: ${countOrders ?? ordersData?.length}`, errO ? `Error: ${JSON.stringify(errO)}` : '');
  if (ordersData && ordersData.length > 0) {
    ordersData.forEach(o => console.log(`   - [Order #${o.id}] Traveller: ${o.traveller_id} | Total: ₹${o.total_amount} | Status: ${o.status}`));
  }

  // 3. SELECT count(*) FROM public.wishlists;
  const { count: countWishlists, data: wishlistsData, error: errW } = await supabase
    .from('wishlists')
    .select('*', { count: 'exact' });
  console.log(`\n3. public.wishlists count: ${countWishlists ?? wishlistsData?.length}`, errW ? `Error: ${JSON.stringify(errW)}` : '');
  if (wishlistsData && wishlistsData.length > 0) {
    wishlistsData.forEach(w => console.log(`   - [Wishlist #${w.id}] Traveller: ${w.traveller_id} | Dest: ${w.destination_id} | Agent: ${w.agent_id} | Product: ${w.product_id}`));
  }

  // 4. SELECT count(*) FROM public.profiles;
  const { count: countProfiles, data: profilesData, error: errP } = await supabase
    .from('profiles')
    .select('*', { count: 'exact' });
  console.log(`\n4. public.profiles count: ${countProfiles ?? profilesData?.length}`, errP ? `Error: ${JSON.stringify(errP)}` : '');
  if (profilesData && profilesData.length > 0) {
    profilesData.forEach(p => console.log(`   - [Profile ID: ${p.id}] Name: ${p.full_name} | Email: ${p.email} | Role: ${p.role}`));
  }

  // 5. Check central sync store in banners.subtitle
  console.log('\n5. Central Sync Store (public.banners.subtitle):');
  const { data: bannerData } = await supabase.from('banners').select('id, title, subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  if (bannerData) {
    console.log('   Banner Subtitle Length:', bannerData.subtitle?.length);
    console.log('   Banner Subtitle Snippet:', bannerData.subtitle?.slice(0, 300) + '...');
  }
}

runStep1Verification();
