import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function findColumns() {
  const { data: auth, error: aErr } = await client.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });


  if (!auth?.user) {
    console.error('Auth login failed:', aErr);
    return;
  }
  const userId = auth.user.id;
  console.log('Logged in User ID:', userId);

  const { data: dRes, error: eRes } = await client
    .from('support_tickets')
    .insert({
      user_id: userId,
      description: 'Need help with booking itinerary',
      status: 'open'
    })
    .select();

  console.log('Ticket Insert Result:', dRes, 'Error:', eRes);
}

findColumns();

