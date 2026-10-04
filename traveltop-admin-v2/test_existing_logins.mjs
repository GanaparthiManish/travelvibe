import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testLogins() {
  const emails = [
    'ganaparthimanish@gmail.com',
    'ecomartx1@gmail.com',
    'real_traveller_test@travelvibe.com',
    'test_1787575900732@example.com',
    'glossysilk_test_1787576336764@gmail.com',
    'ganaparthimanishchowdary@gmail.com'
  ];

  const passwords = ['Ganaparthi@123', 'Password123!', 'password123', 'TestPassword123!'];

  for (const email of emails) {
    for (const pwd of passwords) {
      const { data, error } = await client.auth.signInWithPassword({ email, password: pwd });
      if (data?.user) {
        console.log(`✅ SUCCESS: Email: ${email} | Password: ${pwd} | UUID: ${data.user.id}`);
        break;
      }
    }
  }
}

testLogins();
