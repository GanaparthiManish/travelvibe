import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testOrdersStringAddress() {
  const { data: auth } = await client.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const uid = auth.user.id;
  console.log('Logged in traveller:', uid);

  const { data, error } = await client.from('orders').insert({
    traveller_id: uid,
    items: [{ product_id: 'prod-tent-2p', name: '2-Person Camping Tent', qty: 1, price: 3499 }],
    total_amount: 3499,
    status: 'placed',
    delivery_address: 'Hill View Road, Ooty, 643001'
  }).select().single();

  console.log('Order Insert Result:', data, 'Error:', error?.message);
}

testOrdersStringAddress();
