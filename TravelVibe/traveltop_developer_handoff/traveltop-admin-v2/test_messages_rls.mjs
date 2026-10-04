import { createClient } from '@supabase/supabase-js';

// Use service role key to manage RLS policies
const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
// We need the service role key for admin operations - check .env or ask user
// For now, let's try with the anon key to check current RLS status
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testMessages() {
  // Test reading messages
  const { data, error } = await supabase.from('messages').select('*').limit(5);
  console.log('Read messages:', data?.length, error);

  // Test inserting a message (this will fail with 42501 if RLS blocks it)
  const testMsg = {
    booking_id: '00000000-0000-0000-0000-000000000000',
    sender_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    content: 'test',
    is_read: false,
  };
  const { data: d2, error: e2 } = await supabase.from('messages').insert(testMsg).select();
  console.log('Insert test:', d2, e2);
}

testMessages();
