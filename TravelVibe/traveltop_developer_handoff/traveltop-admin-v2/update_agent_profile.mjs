import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function updateProfile() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  const { error } = await supabase
    .from('profiles')
    .update({
      full_name: 'Priya Sharma (Local Agent)',
      email: 'priya.sharma@traveltop.com',
      phone: '+91 9876543210'
    })
    .eq('id', 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23');

  console.log('Updated Profile Result:', error ? error : 'SUCCESS ✓');
}

updateProfile();
