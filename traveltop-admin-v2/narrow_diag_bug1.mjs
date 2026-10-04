import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkBug1Bookings() {
  console.log('=== BUG 1 DIAGNOSTIC: BOOKINGS TRAVELLER NAME CHECK ===\n');

  // Authenticate as Admin
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const { data: bookings, error: bErr } = await supabase
    .from('bookings')
    .select('id, traveller_id, agent_id, destination, created_at')
    .order('created_at', { ascending: false });

  if (bErr) {
    console.error('Error querying bookings:', bErr);
    return;
  }

  console.log(`Total Bookings in DB: ${bookings.length}`);
  const { data: profiles } = await supabase.from('profiles').select('id, full_name, email');
  const profileMap = new Map((profiles || []).map(p => [p.id, p]));

  for (const b of bookings) {
    const prof = profileMap.get(b.traveller_id);
    const travellerName = prof ? prof.full_name : (b.traveller_id || 'NULL / Missing');
    const isMatched = !!prof;
    console.log(`- Booking ID: ${b.id}`);
    console.log(`  traveller_id: "${b.traveller_id}"`);
    console.log(`  Matched Profile: ${isMatched ? `${prof.full_name} (${prof.email})` : 'NO MATCH FOUND IN PROFILES ("—")'}`);
    console.log(`  Destination: ${b.destination} | Created: ${b.created_at}\n`);
  }
}

checkBug1Bookings();
