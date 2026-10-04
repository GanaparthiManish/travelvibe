import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function fixRealProfile() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  const realName = 'Ganaparthi manish';
  const realEmail = 'ganaparthinarasimha@gmail.com';
  const realPhone = '8897868951';

  console.log('Updating profiles table with real user details...');

  // Update profiles table for ID cdc23bc0-6b3c-4017-b3c5-38b37099bd23
  const { data: pData, error: pErr } = await supabase
    .from('profiles')
    .update({
      full_name: realName,
      email: realEmail,
      phone: realPhone
    })
    .eq('id', 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23');

  if (pErr) {
    console.error('Error updating profiles:', pErr);
  } else {
    console.log('SUCCESS: Profile updated to', realName, realEmail);
  }

  // Also update any other profile matching email
  await supabase
    .from('profiles')
    .update({
      full_name: realName,
      phone: realPhone
    })
    .eq('email', realEmail);

  // Check updated profiles
  const { data: checkData } = await supabase.from('profiles').select('id, full_name, email, phone').eq('email', realEmail);
  console.log('Updated Profile in Database:', checkData);
}

fixRealProfile();
