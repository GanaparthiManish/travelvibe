import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkOrdersSchema() {
  console.log('=== CHECKING ORDERS TABLE SCHEMA & INSERT ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Test inserting with valid UUID vs string
  const uuid = '0713e97c-0000-0000-0000-111111111111';
  const { data: d1, error: e1 } = await supabase.from('orders').insert({
    id: uuid,
    traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    total_amount: 199,
    status: 'placed'
  }).select().single();

  console.log('UUID ID Insert Test:', d1, e1 ? `Error: ${JSON.stringify(e1)}` : 'SUCCESS ✓');

  if (d1?.id) {
    await supabase.from('orders').delete().eq('id', d1.id);
  }
}

checkOrdersSchema();
