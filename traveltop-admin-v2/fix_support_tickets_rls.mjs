import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
// Using Service Role Key to modify RLS / tables directly
const SUPABASE_SERVICE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjUzMzIzOCwiZXhwIjoyMDIxMTA5MjM4fQ.aR2rE0C92L--R3tG3bN_12W3M0wP3y9Z4586';

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function setupSupportTickets() {
  console.log('--- SETTING UP SUPPORT_TICKETS & RLS POLICIES ---');

  // Test inserting using Service Role Client to see if table exists
  const { data, error } = await adminClient
    .from('support_tickets')
    .insert({
      user_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      subject: 'Service Role Test Ticket',
      message: 'System test support ticket for verification.',
      status: 'open'
    })
    .select();

  if (error) {
    console.error('Service role insert error:', error.message);
  } else {
    console.log('Successfully inserted support ticket:', data);
  }
}

setupSupportTickets();
