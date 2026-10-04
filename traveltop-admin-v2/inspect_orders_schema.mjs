import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function inspectOrders() {
  await client.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Test inserting with different payload shapes to identify RLS condition
  const uid = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

  console.log('--- Test 1: Minimal order ---');
  const r1 = await client.from('orders').insert({ traveller_id: uid }).select();
  console.log('R1:', r1.data, 'Err:', r1.error?.message);

  console.log('--- Test 2: Minimal order with total_amount ---');
  const r2 = await client.from('orders').insert({ traveller_id: uid, total_amount: 100 }).select();
  console.log('R2:', r2.data, 'Err:', r2.error?.message);
}

inspectOrders();
