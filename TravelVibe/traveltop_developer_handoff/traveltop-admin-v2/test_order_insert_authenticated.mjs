import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testOrderInsertAuth() {
  console.log('=== TESTING ORDERS INSERT WITH MATCHING AUTH USER ===\n');

  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const userId = authData.user.id;
  console.log(`Authenticated User ID: ${userId}`);

  // Test inserting with valid UUID
  const uuid = '0713e97c-0000-0000-0000-222222222222';
  const { data: d1, error: e1 } = await supabase.from('orders').insert({
    id: uuid,
    traveller_id: userId,
    total_amount: 199,
    status: 'placed'
  }).select().single();

  console.log('Orders Insert Result:', d1, e1 ? `Error: ${JSON.stringify(e1)}` : 'SUCCESS ✓');

  if (d1?.id) {
    await supabase.from('orders').delete().eq('id', d1.id);
  }
}

testOrderInsertAuth();
