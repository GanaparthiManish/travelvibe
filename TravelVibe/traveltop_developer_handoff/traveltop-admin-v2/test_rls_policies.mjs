import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const traveller = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const agent = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testRLSPolicies() {
  const { data: resT, error: errT } = await traveller.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });
  console.log('Traveller Auth:', resT?.user?.id, 'Err:', errT?.message);

  const { data: resA, error: errA } = await agent.auth.signInWithPassword({ email: 'ganaparthimanishchowdary@gmail.com', password: 'Ganaparthi@123' });
  console.log('Agent Auth:', resA?.user?.id, 'Err:', errA?.message);

  const travellerId = resT?.user?.id;
  const agentId = resA?.user?.id;

  // 1. Test Orders Insert & Select
  const { data: ord, error: ordErr } = await traveller.from('orders').insert({
    traveller_id: travellerId,
    items: [{ product_id: 'p1', name: 'Test Product', qty: 1, price: 100 }],
    total_amount: 100,
    status: 'placed'
  }).select().single();

  console.log('Orders Insert Result:', ord?.id, 'Err:', ordErr?.message);

  // 2. Test Booking Insert
  const { data: bk, error: bkErr } = await traveller.from('bookings').insert({
    traveller_id: travellerId,
    agent_id: agentId,
    start_date: '2026-12-01',
    end_date: '2026-12-05',
    total_price: 1000,
    status: 'confirmed',
    destination: 'Test Destination'
  }).select().single();

  console.log('Booking Insert Result:', bk?.id, 'Err:', bkErr?.message);

  if (bk?.id) {
    // 3. Test Messages Insert from Traveller
    const { data: msgT, error: msgTErr } = await traveller.from('messages').insert({
      booking_id: bk.id,
      sender_id: travellerId,
      content: 'Hello from traveller'
    }).select();

    console.log('Traveller Message Insert:', msgT, 'Err:', msgTErr?.message);

    // 4. Test Messages Insert from Agent
    const { data: msgA, error: msgAErr } = await agent.from('messages').insert({
      booking_id: bk.id,
      sender_id: agentId,
      content: 'Hello from agent'
    }).select();

    console.log('Agent Message Insert:', msgA, 'Err:', msgAErr?.message);
  }
}

testRLSPolicies();
