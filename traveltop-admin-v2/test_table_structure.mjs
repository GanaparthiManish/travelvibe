import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testStructure() {
  console.log('--- Testing insert into orders table with UUID id ---');
  const testId = '11111111-2222-3333-4444-555555555555';
  const { data, error } = await supabase.from('orders').insert({
    id: testId,
    traveller_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    items: [{ product_id: 'prod-1', name: 'Test Item', qty: 1, price: 100 }],
    total_amount: 100,
    status: 'placed',
    delivery_address: { phone: '+91 98765 43210' }
  }).select();

  console.log('UUID Insert Result:', data, 'Error:', error);

  if (!error) {
    console.log('Cleaning up test order...');
    await supabase.from('orders').delete().eq('id', testId);
  }
}

testStructure();
