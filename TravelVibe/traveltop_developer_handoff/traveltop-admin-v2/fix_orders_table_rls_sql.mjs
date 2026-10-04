import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkOrdersRLS() {
  console.log('Testing orders insert with anon auth token...');
  const { data: authData, error: authErr } = await supabase.auth.signInAnonymously();

  if (authErr) {
    console.error('Anon auth error:', authErr);
    return;
  }

  console.log('Anon User ID:', authData.user.id);

  const testOrder = {
    traveller_id: authData.user.id,
    items: [{ name: 'Test Bag', price: 100, qty: 1 }],
    total_amount: 100,
    status: 'placed',
    delivery_address: JSON.stringify({ line1: 'Test St', name: 'Test User', email: 'test@example.com' })
  };

  const { data, error } = await supabase.from('orders').insert(testOrder).select();
  if (error) {
    console.error('Orders insert failed:', error);
  } else {
    console.log('Orders insert succeeded!', data);
  }
}

checkOrdersRLS();
