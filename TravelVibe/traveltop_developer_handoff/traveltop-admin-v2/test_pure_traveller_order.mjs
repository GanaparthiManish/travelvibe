import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testPureTraveller() {
  // Sign up a brand new pure traveller user
  const email = `pure_traveller_${Date.now()}@test.com`;
  const { data: signUp, error: sErr } = await client.auth.signUp({
    email,
    password: 'Password123!',
    options: { data: { full_name: 'Pure Traveller', role: 'traveller' } }
  });

  if (sErr) {
    console.error('Sign up error:', sErr.message);
    return;
  }

  const u = signUp.user;
  console.log('Created pure traveller user:', u.id, 'Email:', email);

  // Attempt order insert
  const { data: ord, error: oErr } = await client.from('orders').insert({
    traveller_id: u.id,
    items: [{ product_id: 'p1', name: 'Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    status: 'placed',
    delivery_address: 'Ooty, India'
  }).select();

  console.log('Pure traveller order insert result:', ord, 'Error:', oErr?.message);
}

testPureTraveller();
