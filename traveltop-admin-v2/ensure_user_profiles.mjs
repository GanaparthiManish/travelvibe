import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function ensureUserProfiles() {
  console.log('=== ENSURING REAL TRAVELLER PROFILES IN SUPABASE ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Ensure Eco MartX profile exists as traveller
  await supabase.from('profiles').upsert([
    {
      id: 'ecomartx1@gmail.com',
      email: 'ecomartx1@gmail.com',
      full_name: 'Eco MartX',
      role: 'traveller',
      phone: '+91 88978 68951'
    },
    {
      id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
      email: 'ganaparthimanishchowdary@gmail.com',
      full_name: 'Ganaparthi Manish chowdary',
      role: 'traveller',
      phone: '+91 88978 68951'
    }
  ]);

  console.log('Successfully updated profiles for real users ✓');
}

ensureUserProfiles();
