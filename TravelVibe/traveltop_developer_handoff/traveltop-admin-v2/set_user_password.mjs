import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function fixLogin() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  const email = 'ganaparthinarasimha@gmail.com';
  const password = 'Ganaparthi@123';
  const fullName = 'Ganaparthi manish';
  const phone = '8897868951';

  console.log('Attempting sign up or password update for:', email);

  // 1. Try signUp
  const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName,
        phone: phone,
        role: 'agent'
      }
    }
  });

  if (signUpError) {
    console.log('SignUp result notice:', signUpError.message);
  } else {
    console.log('SignUp SUCCESS:', signUpData.user?.id);
  }

  // 2. Try signIn
  const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
    email,
    password
  });

  if (signInError) {
    console.log('SignIn result error:', signInError.message);
  } else {
    console.log('SignIn SUCCESS! User ID:', signInData.user?.id);
  }
}

fixLogin();
