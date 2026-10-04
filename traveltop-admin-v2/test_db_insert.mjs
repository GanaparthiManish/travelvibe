import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testInsert() {
  console.log('Testing Orders Table Insert with Anon Key...');
  const { data, error } = await supabase.from('orders').insert({
    traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    items: [{ name: 'Test Gear', qty: 1, price: 999 }],
    total_amount: 999,
    status: 'placed',
    delivery_address: 'Test Address'
  }).select();

  if (error) {
    console.error('Insert Failed:', error);
  } else {
    console.log('Insert Succeeded!', data);
  }
}

testInsert();
