import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function check() {
  console.log('--- CHECKING DESTINATION GALLERY & REVIEWS SCHEMA ---');
  
  const { data: imgData, error: imgErr } = await supabase.from('destination_images').select('*').limit(1);
  console.log('destination_images:', imgErr ? `❌ ${imgErr.message}` : `✅ Table exists`);

  const { data: revData, error: revErr } = await supabase.from('destination_reviews').select('*').limit(1);
  console.log('destination_reviews:', revErr ? `❌ ${revErr.message}` : `✅ Table exists`);

  const { data: revImgData, error: revImgErr } = await supabase.from('destination_review_images').select('*').limit(1);
  console.log('destination_review_images:', revImgErr ? `❌ ${revImgErr.message}` : `✅ Table exists`);

  const { data: destData, error: destErr } = await supabase.from('destinations').select('id, name, cover_image_url, rating_avg, review_count').limit(1);
  console.log('destinations rating columns:', destErr ? `❌ ${destErr.message}` : `✅ Columns rating_avg & review_count exist`);
}

check();
