import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkBug2Orders() {
  console.log('=== BUG 2 DIAGNOSTIC: ORDERS COUNT CHECK ===\n');
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // 1. Query public.orders DB table
  const { data: dbOrders, count: dbCount, error: dbErr } = await supabase
    .from('orders')
    .select('id, traveller_id, total_amount, status, created_at', { count: 'exact' });

  console.log(`1. public.orders DB table count: ${dbCount ?? dbOrders?.length}`);
  if (dbOrders) {
    dbOrders.forEach(o => console.log(`   - DB Order #${o.id} | Traveller: ${o.traveller_id} | ₹${o.total_amount}`));
  }

  // 2. Query banners central store ORDERS_SYNC
  const { data: bRes } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  const sub = bRes?.subtitle || '';
  let syncOrders = [];
  if (sub.includes('ORDERS_SYNC:')) {
    let oStr = sub.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
      if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
    }
    try { syncOrders = JSON.parse(oStr); } catch (e) { console.error('Parse error:', e); }
  }

  console.log(`\n2. banners.subtitle ORDERS_SYNC count: ${syncOrders.length}`);
  syncOrders.forEach(o => console.log(`   - Sync Order #${o.id} | Traveller: ${o.traveller_name || o.traveller_id} | ₹${o.total_amount}`));
}

checkBug2Orders();
