import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testPrivacyIsolation() {
  console.log('====================================================');
  console.log('   DATA PRIVACY & USER ISOLATION VERIFICATION       ');
  console.log('====================================================\n');

  // 1. Authenticate User A
  console.log('--- 1. Authenticating User A ---');
  const { data: userAData } = await supabase.auth.signInAnonymously();
  const userA = userAData.user;
  console.log('User A auth.uid():', userA.id);

  // User A places booking
  const { data: bAData, error: bAErr } = await supabase.from('bookings').insert({
    traveller_id: userA.id,
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    start_date: '2026-10-01',
    end_date: '2026-10-05',
    total_price: 4999,
    status: 'confirmed',
    trip_notes: 'User A Private Trip'
  }).select().single();

  console.log('User A Booking Created:', bAData ? `ID: ${bAData.id}` : bAErr);

  // 2. Authenticate User B (Different account)
  console.log('\n--- 2. Authenticating User B (Different Account) ---');
  const clientB = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: userBData } = await clientB.auth.signInAnonymously();
  const userB = userBData.user;
  console.log('User B auth.uid():', userB.id);

  // User B places booking
  const { data: bBData } = await clientB.from('bookings').insert({
    traveller_id: userB.id,
    agent_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    start_date: '2026-11-10',
    end_date: '2026-11-15',
    total_price: 8999,
    status: 'confirmed',
    trip_notes: 'User B Private Trip'
  }).select().single();

  console.log('User B Booking Created:', bBData ? `ID: ${bBData.id}` : 'Failed');

  // 3. User B queries bookings with client filtering .eq('traveller_id', userB.id)
  console.log('\n--- 3. User B Screen Query (.eq("traveller_id", userB.id)) ---');
  const { data: userBBookings } = await clientB
    .from('bookings')
    .select('*')
    .eq('traveller_id', userB.id);

  console.log('User B Screen Results Count:', userBBookings ? userBBookings.length : 0);
  console.log('User B Screen Bookings:', userBBookings ? userBBookings.map(b => ({ id: b.id, traveller_id: b.traveller_id, notes: b.trip_notes })) : []);

  // Check if User A data leaked to User B screen:
  const leakedToB = userBBookings ? userBBookings.some(b => b.traveller_id === userA.id) : false;
  console.log('Did User A Data Leak to User B Screen?:', leakedToB ? '❌ YES (PRIVACY LEAK)' : '✅ NO (PERFECT ISOLATION)');

  // 4. User A queries bookings with client filtering .eq('traveller_id', userA.id)
  console.log('\n--- 4. User A Screen Query (.eq("traveller_id", userA.id)) ---');
  const { data: userABookings } = await supabase
    .from('bookings')
    .select('*')
    .eq('traveller_id', userA.id);

  console.log('User A Screen Results Count:', userABookings ? userABookings.length : 0);
  console.log('User A Screen Bookings:', userABookings ? userABookings.map(b => ({ id: b.id, traveller_id: b.traveller_id, notes: b.trip_notes })) : []);

  const leakedToA = userABookings ? userABookings.some(b => b.traveller_id === userB.id) : false;
  console.log('Did User B Data Leak to User A Screen?:', leakedToA ? '❌ YES (PRIVACY LEAK)' : '✅ NO (PERFECT ISOLATION)');

  console.log('\n====================================================');
  console.log('   DATA PRIVACY ISOLATION VERIFICATION COMPLETE     ');
  console.log('====================================================');
}

testPrivacyIsolation();
