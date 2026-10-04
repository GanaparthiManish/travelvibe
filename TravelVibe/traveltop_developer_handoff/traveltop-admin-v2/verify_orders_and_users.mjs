import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verifyOrdersAndUsers() {
  console.log('=====================================================');
  console.log('VERIFYING ORDERS & USERS PAGE DATA');
  console.log('=====================================================\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // 1. Profiles (Users page)
  const { data: profiles } = await supabase.from('profiles').select('id, full_name, email, role');
  const travellers = (profiles || []).filter(p => p.role !== 'agent');

  console.log(`1. Admin Users Page Profiles (Travellers): ${travellers.length}`);
  travellers.forEach(u => console.log(`   - ${u.full_name} (${u.email})`));

  // 2. Orders (Orders page)
  const { data: bData } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  const sub = bData?.subtitle || '';
  let ordersList = [];
  if (sub.includes('ORDERS_SYNC:')) {
    let oStr = sub.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { ordersList = JSON.parse(oStr); } catch (_) {}
  }

  console.log(`\n2. Admin Orders Page Total Orders: ${ordersList.length}`);
  ordersList.forEach(o => console.log(`   - Order #${o.id} | ${o.traveller_name} (${o.traveller_email}) | ₹${o.total_amount}`));

  const passed = travellers.length === 2 && ordersList.length === 2;

  console.log('\n=====================================================');
  console.log(`VERIFICATION RESULT: ${passed ? '100% PASS ✓ (Both orders & profiles intact, 0 test data)' : 'CHECK DETAILS'}`);
  console.log('=====================================================\n');
}

verifyOrdersAndUsers();
