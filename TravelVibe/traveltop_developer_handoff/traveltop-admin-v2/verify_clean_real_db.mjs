import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verifyCleanRealDb() {
  console.log('=== VERIFYING REAL DATABASE RECORDS IN SUPABASE ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // 1. Profiles
  const { data: profiles } = await supabase.from('profiles').select('id, full_name, email, role');
  console.log(`1. Total Profiles in DB: ${profiles?.length || 0}`);
  profiles?.forEach(p => console.log(`   - [${p.role}] ${p.full_name} (${p.email}) | ID: ${p.id}`));

  // 2. Bookings
  const { data: bookings } = await supabase.from('bookings').select('id, traveller_id, destination, total_price, status, created_at');
  console.log(`\n2. Total Bookings in DB: ${bookings?.length || 0}`);
  bookings?.forEach(b => console.log(`   - Booking #${b.id} | Traveller: ${b.traveller_id} | ${b.destination} | ₹${b.total_price} (${b.status})`));

  // 3. Wishlists
  const { data: wishlists } = await supabase.from('wishlists').select('id, traveller_id, destination_id, agent_id, product_id');
  console.log(`\n3. Total Wishlists in DB: ${wishlists?.length || 0}`);
  wishlists?.forEach(w => console.log(`   - Wishlist #${w.id} | Traveller: ${w.traveller_id} | Dest: ${w.destination_id} | Agent: ${w.agent_id}`));

  // 4. Central Store (banners.subtitle)
  const { data: bRes } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  console.log(`\n4. Central Sync Store Length: ${bRes?.subtitle?.length || 0} bytes`);
}

verifyCleanRealDb();
