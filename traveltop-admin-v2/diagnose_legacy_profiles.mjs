import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function diagnoseLegacyProfiles() {
  console.log('--- AUDITING PROFILES TABLE ---');
  const { data: profiles, error } = await supabase.from('profiles').select('id, email, full_name, role, created_at');

  if (error) {
    console.error('Error fetching profiles:', error);
    return;
  }

  console.log(`Total profiles found in database: ${profiles.length}\n`);
  for (const p of profiles) {
    console.log(`- Profile ID: ${p.id} | Email: ${p.email} | Name: ${p.full_name} | Role: ${p.role}`);
  }
}

diagnoseLegacyProfiles();
