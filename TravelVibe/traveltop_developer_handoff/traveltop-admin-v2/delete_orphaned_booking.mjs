import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function deleteOrphanedBooking() {
  console.log('=== CLEANING ONLY SPECIFIC ORPHANED TEST BOOKING ===');
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const targetId = '0713e97c-0000-0000-0000-000000000001';

  const { data, error } = await supabase
    .from('bookings')
    .delete()
    .eq('id', targetId)
    .select();

  console.log(`Deleted orphaned booking #${targetId}:`, data, error ? `Error: ${JSON.stringify(error)}` : 'Success ✓');
}

deleteOrphanedBooking();
