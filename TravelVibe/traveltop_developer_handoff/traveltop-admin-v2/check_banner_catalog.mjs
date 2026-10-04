import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkBanner() {
  const { data, error } = await supabase
    .from('banners')
    .select('subtitle')
    .eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985')
    .maybeSingle();

  if (error) {
    console.error('Fetch error:', error);
  } else {
    console.log('Banner subtitle:', data ? data.subtitle : null);
  }
}

checkBanner();
