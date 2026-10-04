import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAllInserts() {
  console.log('--- Testing INSERT Permissions Across Tables ---');

  const { data: authData } = await supabase.auth.signInAnonymously();
  const uid = authData.user.id;

  // Bookings with 'confirmed' status
  const { error: bkErr } = await supabase.from('bookings').insert({
    traveller_id: uid,
    agent_id: 'a7b8c9d0-1111-2222-3333-444455556666',
    start_date: '2026-09-01',
    end_date: '2026-09-03',
    total_price: 2500,
    status: 'confirmed',
    trip_notes: 'Audit booking'
  });
  console.log('3. Bookings INSERT with status confirmed:', bkErr ? `❌ ${bkErr.message} (Code: ${bkErr.code})` : '✅ Success');
}

testAllInserts();
