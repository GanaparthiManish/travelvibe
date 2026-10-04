import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testOrdersMinimal() {
  const { data: auth } = await client.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const uid = auth.user.id;
  console.log('Logged in user:', uid);

  // Test 1: plain object delivery_address (JSON) vs string
  console.log('\n--- Test A: jsonb items + string address ---');
  const resA = await client.from('orders').insert({
    traveller_id: uid,
    items: [{ product_id: 'p1', name: 'Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    status: 'placed',
    delivery_address: 'Ooty, India'
  }).select();
  console.log('ResA:', resA.data, 'ErrA:', resA.error?.message);

  console.log('\n--- Test B: jsonb items + json object address ---');
  const resB = await client.from('orders').insert({
    traveller_id: uid,
    items: [{ product_id: 'p1', name: 'Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    status: 'placed',
    delivery_address: JSON.stringify({ line1: 'Ooty, India' })
  }).select();
  console.log('ResB:', resB.data, 'ErrB:', resB.error?.message);
}

testOrdersMinimal();
