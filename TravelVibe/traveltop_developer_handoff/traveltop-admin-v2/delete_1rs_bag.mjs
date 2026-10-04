import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function deleteBag() {
  console.log('Logging in as Admin to delete ₹1 bag product...');
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Admin Auth Failed:', authErr);
    return;
  }

  console.log('Admin Auth Succeeded! Deleting ₹1 bag product...');

  const { data, error } = await supabase
    .from('products')
    .delete()
    .or('price.eq.1,name.ilike.%bag%')
    .select();

  if (error) {
    console.error('Delete failed:', error);
  } else {
    console.log('Deleted ₹1 test products successfully!', data);
  }
}

deleteBag();
