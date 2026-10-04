import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testWishlistSchema() {
  console.log('--- Testing insert into wishlists table ---');
  const { data, error } = await supabase.from('wishlists').insert({
    traveller_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    destination_id: 'dest-1'
  }).select();

  console.log('Wishlist UUID Insert:', data, 'Error:', error);

  const { data: d2, error: e2 } = await supabase.from('wishlists').insert({
    traveller_id: 'ecomartx1@gmail.com',
    destination_id: 'dest-1'
  }).select();

  console.log('Wishlist Email Insert:', d2, 'Error:', e2);
}

testWishlistSchema();
