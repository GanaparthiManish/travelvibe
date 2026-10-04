import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkOrders() {
  const { data: auth, error } = await client.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  console.log('Logged in user:', auth?.user?.id, 'Error:', error?.message);

  const { data, error: selectErr } = await client.from('orders').select('*').limit(5);
  console.log('Orders Select Result:', data, 'Select Err:', selectErr?.message);

  const { data: ins, error: insErr } = await client.from('orders').insert({
    traveller_id: auth?.user?.id,
    items: [{ product_id: 'prod-test', name: 'Test Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    status: 'placed'
  }).select();
  console.log('Orders Insert Result:', ins, 'Insert Err:', insErr?.message);
}

checkOrders();
