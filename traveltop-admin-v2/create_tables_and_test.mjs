import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testTables() {
  console.log('=== TESTING SUPABASE TABLES FOR FLEXIBLE PRICING ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // 1. Check agent_addons
  const { data: addons, error: errAddons } = await supabase.from('agent_addons').select('*');
  console.log('agent_addons table:', addons ? `Count: ${addons.length}` : `Error: ${errAddons?.message}`);

  // 2. Check inquiries
  const { data: inq, error: errInq } = await supabase.from('inquiries').select('*');
  console.log('inquiries table:', inq ? `Count: ${inq.length}` : `Error: ${errInq?.message}`);

  // 3. Check bookings columns
  const { data: book, error: errBook } = await supabase.from('bookings').select('id, selected_addons, base_price, negotiated_price').limit(1);
  console.log('bookings columns check:', book ? 'SUCCESS ✓' : `Error: ${errBook?.message}`);

  // 4. Check messages columns
  const { data: msg, error: errMsg } = await supabase.from('messages').select('id, inquiry_id').limit(1);
  console.log('messages inquiry_id check:', msg ? 'SUCCESS ✓' : `Error: ${errMsg?.message}`);
}

testTables();
