import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function insertEcoMartxProfile() {
  console.log('=== INSERTING ECOMARTX PROFILE ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Get user ID from auth.users or profiles
  const { data: profs } = await supabase.from('profiles').select('*');
  console.log('Current Profiles:', profs);

  // Insert Eco MartX profile row if missing
  const { data, error } = await supabase.from('profiles').insert({
    id: '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07', // existing UUID for Eco MartX / Nani Manish
    email: 'ecomartx1@gmail.com',
    full_name: 'Eco MartX',
    role: 'traveller',
    phone: '+91 88978 68951'
  }).select();

  console.log('Profile Insert Result:', data, error ? `Error: ${JSON.stringify(error)}` : 'SUCCESS ✓');
}

insertEcoMartxProfile();
