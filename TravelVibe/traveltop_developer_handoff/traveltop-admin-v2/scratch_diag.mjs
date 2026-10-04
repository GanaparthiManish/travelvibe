import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function deepDiag() {
  console.log('=== DEEP DIAGNOSTIC ===\n');

  // 1. ALL PROFILES IN DETAIL
  console.log('--- ALL PROFILES ---');
  const { data: profiles, error: pErr } = await supabase.from('profiles').select('*');
  console.log('pErr:', pErr);
  console.log(`Total profiles returned: ${profiles?.length}`);
  profiles?.forEach(p => console.log(`- ID: ${p.id} | Role: "${p.role}" | Name: "${p.full_name}" | Email: "${p.email}"`));

  // 2. CHECK USERS.JSX QUERY SIMULATION
  console.log('\n--- SIMULATING USERS.JSX QUERY ---');
  let q = supabase.from('profiles').select('*', { count: 'exact' });
  const { data: uData, error: uErr } = await q;
  console.log('uErr:', uErr);
  console.log('uData count:', uData?.length);
  
  let travellersMap = new Map();
  (uData || []).filter(p => p.role !== 'agent').forEach(p => {
    travellersMap.set(p.email || p.id, {
      ...p,
      role: 'traveller',
    });
  });
  console.log('travellersMap entries (filter role !== agent):', travellersMap.size);
  travellersMap.forEach((val, key) => console.log('  key:', key, '=>', val.full_name, val.email, val.role));

  // 3. CHECK ORDERS.JSX QUERY SIMULATION
  console.log('\n--- SIMULATING ORDERS.JSX QUERY ---');
  let dbOrders = [];
  const { data: oData, error: oErr } = await supabase.from('orders').select('*', { count: 'exact' });
  console.log('Orders query error:', oErr);
  console.log('Orders query data:', oData);
  if (oData) dbOrders = oData;

  const { data: bData, error: bErr } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  console.log('Banner query error:', bErr);
  let bannerOrders = [];
  if (bData?.subtitle && bData.subtitle.includes('ORDERS_SYNC:')) {
    let oStr = bData.subtitle.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
    }
    bannerOrders = JSON.parse(oStr);
  }
  console.log('bannerOrders parsed count:', bannerOrders.length);
  console.log('bannerOrders raw:', bannerOrders);

  const allOrders = [...dbOrders];
  for (const bo of bannerOrders) {
    if (!allOrders.some(o => o.id === bo.id)) {
      allOrders.push(bo);
    }
  }
  console.log('Combined allOrders count in Orders.jsx:', allOrders.length);

  // 4. CHECK RLS ON PROFILES, ORDERS, BANNERS, ADMIN_USERS
  console.log('\n--- CHECKING RLS AND AUTH ---');
  // Attempting to sign in with admin credentials if known or check auth users
  const { data: adminUsers } = await supabase.from('admin_users').select('*');
  console.log('admin_users:', adminUsers);

  // Let's check why shop_screen in flutter Flutter app order creation didn't save to orders table or failed
}

deepDiag();
