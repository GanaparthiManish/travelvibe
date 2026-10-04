import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testCleanUser() {
  const testEmail = `testuser_${Date.now()}@travelvibe.com`;
  const testPass = 'TravelVibePass123!';

  console.log(`1. Creating fresh non-suspended account: ${testEmail}...`);
  const { data: signUpData, error: sErr } = await supabase.auth.signUp({
    email: testEmail,
    password: testPass,
    options: {
      data: { full_name: 'Test Traveller User', role: 'traveller' }
    }
  });

  if (sErr) {
    console.error('Signup error:', sErr.message);
    return;
  }

  const userId = signUpData.user.id;
  console.log('Registered User ID:', userId);

  // Ensure profile
  await supabase.from('profiles').upsert({
    id: userId,
    email: testEmail,
    full_name: 'Test Traveller User',
    role: 'traveller',
    suspended: false
  });

  console.log('2. Inserting Support Ticket...');
  const { data: ticketData, error: tErr } = await supabase
    .from('support_tickets')
    .insert({
      user_id: userId,
      subject: 'Fresh User Support Ticket',
      message: 'Hello, this is a test inquiry about local guide bookings.',
      status: 'open'
    })
    .select();

  if (tErr) {
    console.error('Support ticket insert error:', tErr);
  } else {
    console.log('Support Ticket Inserted Successfully! Data:', ticketData);
  }

  console.log('3. Fetching User Support Tickets...');
  const { data: myTickets, error: fErr } = await supabase
    .from('support_tickets')
    .select('*')
    .eq('user_id', userId);

  console.log('Fetched Support Tickets Count:', myTickets?.length);
  console.log('Tickets:', JSON.stringify(myTickets, null, 2));
}

testCleanUser();
