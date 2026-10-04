import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testWishlistNarrow() {
  console.log('=== WISHLIST NARROW TEST ===\n');

  // Authenticate as ganaparthimanish@gmail.com
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const userId = authData.user.id;
  console.log(`1. Authenticated User ID: ${userId}`);

  // Insert a test wishlist item directly
  const { data: insertData, error: insertErr } = await supabase.from('wishlists').insert({
    traveller_id: userId,
    destination_id: '4f1047d2-474a-4c1f-9515-8764ac40ecba'
  }).select().single();

  console.log('2. Insert Outcome:', insertErr ? `ERROR: ${insertErr.message}` : `SUCCESS (Inserted ID: ${insertData?.id})`);

  // Query wishlist rows for this traveller_id
  const { data: rows, error: selErr } = await supabase
    .from('wishlists')
    .select('*')
    .eq('traveller_id', userId);

  console.log(`3. Query Outcome: Found ${rows?.length || 0} rows for traveller_id '${userId}'`, selErr ? `Error: ${selErr.message}` : '');
  if (rows) {
    rows.forEach(r => console.log(`   - Wishlist #${r.id} | Dest: ${r.destination_id} | Agent: ${r.agent_id}`));
  }
}

testWishlistNarrow();
