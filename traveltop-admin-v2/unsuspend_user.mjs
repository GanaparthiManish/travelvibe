import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function unsuspendUser() {
  console.log('--- UN-SUSPENDING USER PROFILES ---');
  
  // Unsuspend ganaparthimanishchowdary@gmail.com
  const { data: updated, error } = await supabase
    .from('profiles')
    .update({ suspended: false })
    .ilike('email', '%ganaparthimanish%')
    .select();

  console.log('Update error:', error);
  console.log('Updated profiles:', updated);
}

unsuspendUser();
