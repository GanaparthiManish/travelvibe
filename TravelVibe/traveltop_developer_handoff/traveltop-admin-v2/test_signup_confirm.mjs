import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function testSignupConfirm() {
  const c1 = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const c2 = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const tEmail = `t_user_${Date.now()}@travelvibe.com`;
  const aEmail = `a_user_${Date.now()}@travelvibe.com`;

  const { data: sT, error: eT } = await c1.auth.signUp({ email: tEmail, password: 'Password123!' });
  console.log('Traveller SignUp Result:', sT?.user?.id, 'Session:', !!sT?.session, 'Err:', eT?.message);

  const { data: sA, error: eA } = await c2.auth.signUp({ email: aEmail, password: 'Password123!' });
  console.log('Agent SignUp Result:', sA?.user?.id, 'Session:', !!sA?.session, 'Err:', eA?.message);

  if (sT?.user?.id && sA?.user?.id) {
    // Insert profile and agent_details
    await c1.from('profiles').insert({ id: sT.user.id, email: tEmail, full_name: 'Live Traveller Test', role: 'traveller' });
    await c2.from('profiles').insert({ id: sA.user.id, email: aEmail, full_name: 'Live Agent Test', role: 'agent' });
    await c2.from('agent_details').insert({ id: sA.user.id, verification_status: 'approved', price_per_day: 2000 });

    // Test Orders Insert
    const { data: o, error: oErr } = await c1.from('orders').insert({
      traveller_id: sT.user.id,
      items: [{ product_id: 'p1', name: 'Test Tent', qty: 1, price: 1000 }],
      total_amount: 1000,
      status: 'placed'
    }).select();
    console.log('Order Insert Result:', o, 'Err:', oErr?.message);

    // Test Booking Insert
    const { data: b, error: bErr } = await c1.from('bookings').insert({
      traveller_id: sT.user.id,
      agent_id: sA.user.id,
      start_date: '2026-12-01',
      end_date: '2026-12-05',
      total_price: 5000,
      status: 'confirmed',
      destination: 'Test Destination'
    }).select().single();
    console.log('Booking Insert Result:', b?.id, 'Err:', bErr?.message);

    // Test Message Insert from Agent
    const { data: m, error: mErr } = await c2.from('messages').insert({
      booking_id: b.id,
      sender_id: sA.user.id,
      content: 'Agent live reply test'
    }).select();
    console.log('Agent Message Insert Result:', m, 'Err:', mErr?.message);
  }
}

testSignupConfirm();
