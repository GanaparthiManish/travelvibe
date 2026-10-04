import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAnon() {
  console.log('Signing in anonymously...');
  const { data: authData, error: authErr } = await supabase.auth.signInAnonymously();

  if (authErr) {
    console.error('Anon Auth Failed:', authErr);
    return;
  }

  console.log('Anon Auth Succeeded! User ID:', authData.user.id);
  console.log('Testing Insert as Anon Authenticated User...');

  const { data, error } = await supabase.from('orders').insert({
    traveller_id: authData.user.id,
    items: [{ name: 'Test Gear', qty: 1, price: 100 }],
    total_amount: 100,
    status: 'placed',
    delivery_address: 'Test Address'
  }).select();

  if (error) {
    console.error('Insert as Anon Auth Failed:', error);
  } else {
    console.log('Insert as Anon Auth Succeeded! Data:', data);
  }
}

testAnon();
