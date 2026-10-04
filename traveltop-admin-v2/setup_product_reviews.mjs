import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function setupReviews() {
  console.log('Testing product_reviews table...');
  const { data: prods } = await supabase.from('products').select('id, name');
  console.log('Found products:', prods?.length);

  const { data: revs, error: rErr } = await supabase.from('product_reviews').select('*').limit(5);
  console.log('Product reviews:', revs, rErr);
}

setupReviews();
