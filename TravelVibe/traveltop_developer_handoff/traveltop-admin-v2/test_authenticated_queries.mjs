import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAuthQueries() {
  console.log('=== AUTHENTICATED ADMIN QUERY TEST ===');

  // 1. Sign in as admin
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Auth error:', authErr);
    return;
  }

  const user = authData.user;
  console.log(`Successfully authenticated as ${user.email} (UID: ${user.id})`);

  // 2. Test is_admin() RPC
  const { data: isAdmin, error: rpcErr } = await supabase.rpc('is_admin');
  console.log('RPC is_admin() result:', isAdmin, 'error:', rpcErr);

  // 3. Query admin_users table
  const { data: adminRow, error: adminErr } = await supabase
    .from('admin_users')
    .select('*')
    .eq('id', user.id);
  console.log('admin_users row for this admin UID:', adminRow, 'error:', adminErr);

  // 4. Query profiles table
  const { data: profiles, error: profErr, count: profCount } = await supabase
    .from('profiles')
    .select('*', { count: 'exact' });
  console.log(`Profiles query (Authenticated): count = ${profCount}, returned length = ${profiles?.length}`, 'error:', profErr);
  if (profiles) {
    profiles.forEach(p => console.log(`- ID: ${p.id} | Role: "${p.role}" | Name: "${p.full_name}" | Email: "${p.email}"`));
  }

  // 5. Query orders table
  const { data: orders, error: ordErr, count: ordCount } = await supabase
    .from('orders')
    .select('*', { count: 'exact' });
  console.log(`Orders query (Authenticated): count = ${ordCount}, returned length = ${orders?.length}`, 'error:', ordErr);

  // 6. Query banners table (ORDERS_SYNC)
  const { data: bData, error: bErr } = await supabase
    .from('banners')
    .select('subtitle')
    .eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985')
    .maybeSingle();
  console.log('Banners subtitle query (Authenticated): error:', bErr);
  if (bData?.subtitle && bData.subtitle.includes('ORDERS_SYNC:')) {
    let oStr = bData.subtitle.split('ORDERS_SYNC:')[1].trim();
    for (const k of ['BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:']) {
      if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
    }
    const bannerOrders = JSON.parse(oStr);
    console.log(`Banners ORDERS_SYNC order count = ${bannerOrders.length}`);
    console.log('Banner orders:', bannerOrders.map(o => ({ id: o.id, traveller_name: o.traveller_name, status: o.status })));
  }
}

testAuthQueries();
