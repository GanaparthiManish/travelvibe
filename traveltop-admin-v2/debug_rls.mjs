import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabaseTraveller = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const supabaseAgent = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function debugRLS() {
  const { data: authT } = await supabaseTraveller.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123',
  });
  const travellerId = authT.user.id;

  const { data: authA } = await supabaseAgent.auth.signInWithPassword({
    email: 'ganaparthimanishchowdary@gmail.com',
    password: 'Ganaparthi@123',
  });
  const agentId = authA.user.id;

  console.log('Traveller UID:', travellerId);
  console.log('Agent UID:', agentId);

  // Test Orders Insert from Traveller
  const { data: o, error: oErr } = await supabaseTraveller.from('orders').insert({
    traveller_id: travellerId,
    items: [{ product_id: 'p1', name: 'Test Tent', qty: 1, price: 1000 }],
    total_amount: 1000,
    status: 'placed',
    delivery_address: { city: 'Ooty' }
  }).select().single();

  console.log('Order Insert Result:', o?.id, 'Error:', oErr?.message);

  // Test Booking Insert from Traveller
  const { data: b, error: bErr } = await supabaseTraveller.from('bookings').insert({
    traveller_id: travellerId,
    agent_id: agentId,
    start_date: '2026-12-10',
    end_date: '2026-12-15',
    total_price: 5000,
    status: 'confirmed',
    destination: 'Test Destination'
  }).select().single();

  console.log('Booking Insert Result:', b?.id, 'Error:', bErr?.message);

  if (b?.id) {
    // Test Message Insert from Traveller
    const { data: m1, error: m1Err } = await supabaseTraveller.from('messages').insert({
      booking_id: b.id,
      sender_id: travellerId,
      content: 'Traveller msg',
      is_read: false
    }).select();
    console.log('Traveller Message Insert:', m1, 'Error:', m1Err?.message);

    // Test Message Insert from Agent
    const { data: m2, error: m2Err } = await supabaseAgent.from('messages').insert({
      booking_id: b.id,
      sender_id: agentId,
      content: 'Agent msg',
      is_read: false
    }).select();
    console.log('Agent Message Insert:', m2, 'Error:', m2Err?.message);
  }
}

debugRLS();
