import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAdminDeleteOrder() {
  const { data: auth } = await client.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const uid = auth.user.id;

  // 1. Temporarily remove from admin_users to test if pure traveller RLS works
  const { data: delAdmin } = await client.from('admin_users').delete().eq('id', uid).select();
  console.log('Removed from admin_users:', delAdmin);

  // 2. Insert order
  const { data: ord, error: oErr } = await client.from('orders').insert({
    traveller_id: uid,
    items: [{ product_id: 'p1', name: 'Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    status: 'placed',
    delivery_address: 'Ooty, India'
  }).select();

  console.log('Order insert as pure traveller result:', ord, 'Err:', oErr?.message);

  // 3. Restore to admin_users
  const { data: insAdmin } = await client.from('admin_users').insert({
    id: uid,
    full_name: 'Manish Ganaparthi',
    role: 'super_admin',
    email: 'ganaparthimanish@gmail.com',
    active: true
  }).select();
  console.log('Restored to admin_users:', insAdmin);
}

testAdminDeleteOrder();
