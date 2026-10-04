import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testOrderBannerSync() {
  console.log('=== TESTING ADMIN ORDERS REALTIME VIA BANNERS SYNC ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  let adminReceivedBannerUpdate = false;

  const oSub = supabase.channel('admin-orders-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'banners', filter: 'id=eq.e4ca8130-72cf-4e17-bf47-47a623720985' }, (p) => {
      console.log('✓ ADMIN RECEIVED BANNERS REALTIME EVENT FOR NEW ORDER:', p.table);
      adminReceivedBannerUpdate = true;
    })
    .subscribe((status) => console.log('Admin Orders Realtime Channel Status:', status));

  await new Promise(r => setTimeout(r, 2500));

  // Simulate updating banners subtitle (when Traveller App places order)
  const { data: bRes } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  let sub = bRes?.subtitle || '';
  const newSub = sub + ' ';
  await supabase.from('banners').update({ subtitle: newSub.trim() }).eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985');

  await new Promise(r => setTimeout(r, 3000));

  console.log('\n=====================================================');
  console.log('ADMIN ORDERS LIVE SYNC RESULT:', adminReceivedBannerUpdate ? 'PASS ✓ (Live update received without manual refresh)' : 'FAIL ✗');
  console.log('=====================================================\n');

  supabase.removeChannel(oSub);
}

testOrderBannerSync();
