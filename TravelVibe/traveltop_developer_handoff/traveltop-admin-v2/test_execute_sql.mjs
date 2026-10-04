import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testSql() {
  console.log('Logging in as Admin to execute RLS update...');
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Admin Auth Failed:', authErr);
    return;
  }

  console.log('Admin Auth Succeeded! User ID:', authData.user.id);
  console.log('Testing Insert as Authenticated User...');

  const { data, error } = await supabase.from('orders').insert({
    traveller_id: authData.user.id,
    items: [{ name: 'Test Bag', qty: 1, price: 1 }],
    total_amount: 1,
    status: 'placed',
    delivery_address: 'Ooty, India'
  }).select();

  if (error) {
    console.error('Insert as Auth User Failed:', error);
  } else {
    console.log('Insert as Auth User Succeeded! Data:', data);
  }
}

testSql();
