import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
// Standard service role JWT for reference project imretkikrsdydreldosx
const SUPABASE_SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjUzMzIzOCwiZXhwIjoyMDIxMTA5MjM4fQ.5yqW5b6q4bWqg9mR1p2Y3Z4A5B6C7D8E9F0G1H2I3J4';

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

async function confirmEmail() {
  const { data, error } = await adminClient.auth.admin.updateUserById(
    'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    { email_confirm: true }
  );

  console.log('Update User Confirm Status:', data?.user?.email, 'Error:', error?.message);

  // Test sign in as agent
  const anonClient = createClient(SUPABASE_URL, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw');
  const { data: aData, error: aErr } = await anonClient.auth.signInWithPassword({
    email: 'ganaparthimanishchowdary@gmail.com',
    password: 'Ganaparthi@123'
  });

  console.log('Agent Login Status:', aData?.user?.id, 'Error:', aErr?.message);
}

confirmEmail();
