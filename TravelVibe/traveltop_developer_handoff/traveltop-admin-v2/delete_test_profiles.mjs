import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function deleteTestProfiles() {
  console.log('=== DELETING TRANSIENT DUMMY TEST PROFILES & BOOKINGS ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const testEmails = [
    'test_account_a_1787383498131@traveltop.com',
    'test_account_b_1787383498131@traveltop.com',
    'agent_test_1787090102958@traveltop.com',
    'agent_test_1787090061044@traveltop.com',
    'account_a_clean_test@traveltop.com',
    'account_b_clean_test@traveltop.com',
    'flow_test_acc_a@travelvibe.com',
    'flow_test_acc_b@travelvibe.com'
  ];

  // 1. Get IDs of test profiles
  const { data: profs } = await supabase.from('profiles').select('id, email').in('email', testEmails);
  const ids = (profs || []).map(p => p.id);

  if (ids.length > 0) {
    // Delete test bookings
    await supabase.from('bookings').delete().in('traveller_id', ids);
    // Delete test wishlists
    await supabase.from('wishlists').delete().in('traveller_id', ids);
  }

  // 2. Delete test profiles
  const { data: deletedProfs, error: errProf } = await supabase
    .from('profiles')
    .delete()
    .in('email', testEmails)
    .select();

  console.log('Deleted dummy test profiles:', deletedProfs, errProf ? `Error: ${JSON.stringify(errProf)}` : 'SUCCESS ✓');
}

deleteTestProfiles();
