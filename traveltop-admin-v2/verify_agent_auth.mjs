import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testPasswords() {
  const passwords = ['Ganaparthi@123', 'Manish@123', 'Password123!', '12345678', 'agent123'];
  for (const pw of passwords) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: 'ganaparthimanishchowdary@gmail.com',
      password: pw
    });
    console.log(`Password "${pw}":`, data?.user?.id ? 'SUCCESS ✓' : `FAILED (${error?.message})`);
    if (data?.user) break;
  }
}

testPasswords();
