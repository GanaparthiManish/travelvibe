import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testOrdersInsert() {
  console.log('Testing insert into orders table with text id TV-ORD-TEST...');
  const { data, error } = await supabase.from('orders').insert({
    id: 'TV-ORD-TEST123',
    traveller_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    items: [],
    total_amount: 100,
    status: 'placed',
    delivery_address: {}
  }).select();

  console.log('Insert Result:', data, 'Error:', error);
}

testOrdersInsert();
