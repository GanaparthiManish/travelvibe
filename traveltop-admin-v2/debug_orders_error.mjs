import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function debugOrdersError() {
  const { data: auth } = await client.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const uid = auth.user.id;

  const res = await client.from('orders').insert({
    traveller_id: uid,
    items: [{ product_id: 'p1', name: 'Test Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    delivery_address: 'Ooty, India',
    status: 'placed'
  }).select();

  console.log('Insert Result:', res.data);
  console.log('Insert Error Object:', JSON.stringify(res.error, null, 2));
}

debugOrdersError();
