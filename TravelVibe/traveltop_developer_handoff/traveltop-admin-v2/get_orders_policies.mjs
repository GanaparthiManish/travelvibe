import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function getOrdersPolicies() {
  console.log('=== GETTING RLS POLICIES FOR ORDERS TABLE ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Query pg_policies via rpc or select
  const { data, error } = await supabase.rpc('get_policies');
  if (error) {
    // Select directly from wishlists and bookings to compare
    console.log('Testing wishlists insert:');
    const { error: wErr } = await supabase.from('wishlists').insert({
      traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      destination_id: '4f1047d2-474a-4c1f-9515-8764ac40ecba'
    });
    console.log('Wishlist Insert:', wErr ? wErr.message : 'SUCCESS ✓');

    console.log('Testing bookings insert:');
    const { error: bErr } = await supabase.from('bookings').insert({
      traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      destination: 'Test',
      total_price: 100
    });
    console.log('Booking Insert:', bErr ? bErr.message : 'SUCCESS ✓');
  } else {
    console.log('Policies:', data);
  }
}

getOrdersPolicies();
