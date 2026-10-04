import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjUzMzIzOCwiZXhwIjoyMDIxMTA5MjM4fQ.aK63M8Y2n9u06W6S5N6o2W9Z6Z6Z6Z6Z6Z6Z6Z6Z6Z6'; // Let's check service role key or Edge function

// Let's test inserting the products using Admin session first to verify if products exist under Admin
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkAdminProducts() {
  console.log('Logging in as Admin to check products table...');
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const { data, error } = await supabase.from('products').select('*');
  console.log('Admin view products count:', data ? data.length : 0);
  console.log('Admin view products:', data);
}

checkAdminProducts();
