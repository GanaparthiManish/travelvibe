import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testAuthTicket() {
  const { data: auth, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123',
  });

  if (authErr) {
    console.error('Auth error:', authErr.message);
    return;
  }

  const userId = auth.user.id;
  console.log('Authenticated User ID:', userId);

  const { data: inserted, error: insertErr } = await supabase
    .from('support_tickets')
    .insert({
      user_id: userId
    })
    .select();



  console.log('Insert error:', insertErr);
  console.log('Inserted ticket:', inserted);

  const { data: myTickets, error: fetchErr } = await supabase
    .from('support_tickets')
    .select('*')
    .eq('user_id', userId);

  console.log('Fetch error:', fetchErr);
  console.log('My tickets count:', myTickets?.length);
}

testAuthTicket();
