import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verifyAdminJoins() {
  console.log('====================================================');
  console.log('   ADMIN CONSOLE BOOKINGS JOIN QUERY AUDIT         ');
  console.log('====================================================\n');

  // Exact query from Bookings.jsx
  const { data: bookings, error } = await supabase
    .from('bookings')
    .select(`
      id,
      traveller_id,
      agent_id,
      total_price,
      status,
      start_date,
      end_date,
      profiles!traveller_id (id, full_name, email),
      agent_details!agent_id (id, profiles (id, full_name, email))
    `)
    .order('created_at', { ascending: false })
    .limit(5);

  if (error) {
    console.error('Query Error:', error);
    return;
  }

  console.log('Exact Query Output Sample (First 5 Rows):');
  bookings.forEach((b, i) => {
    console.log(`\n[Booking ${i + 1}] ID: ${b.id}`);
    console.log(`  - Traveller Foreign Key ID (traveller_id): ${b.traveller_id}`);
    console.log(`  - Joined Traveller Profile:`, b.profiles);
    console.log(`  - Match Verified?: ${b.profiles ? (b.traveller_id === b.profiles.id ? '✅ MATCHED CORRECTLY' : '❌ MISMATCHED') : '⚠️ No profile row'}`);

    console.log(`  - Agent Foreign Key ID (agent_id): ${b.agent_id}`);
    console.log(`  - Joined Agent Profile:`, b.agent_details?.profiles);
    console.log(`  - Match Verified?: ${b.agent_details?.profiles ? (b.agent_id === b.agent_details.profiles.id ? '✅ MATCHED CORRECTLY' : '❌ MISMATCHED') : '⚠️ No agent profile'}`);
  });

  console.log('\n====================================================');
  console.log('   ADMIN JOIN QUERY VERIFICATION COMPLETE           ');
  console.log('====================================================');
}

verifyAdminJoins();
