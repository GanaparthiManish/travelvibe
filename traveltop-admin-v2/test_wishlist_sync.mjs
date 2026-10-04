import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testWishlistCentralSync() {
  console.log('Testing Wishlist Central Sync in banners.subtitle...');

  const { data: bData } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  let sub = bData?.subtitle || '';
  console.log('Current subtitle length:', sub.length);

  let wishlistMap = {};
  if (sub.includes('WISHLIST_SYNC:')) {
    let wStr = sub.split('WISHLIST_SYNC:')[1].trim();
    for (const k of ['ORDERS_SYNC:', 'BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:']) {
      if (wStr.includes(' ' + k)) wStr = wStr.split(' ' + k)[0].trim();
      if (wStr.includes(k)) wStr = wStr.split(k)[0].trim();
    }
    try {
      wishlistMap = JSON.parse(wStr);
    } catch (e) {
      console.error('Parsing WISHLIST_SYNC error:', e);
    }
  }

  // Update sample user wishlist
  wishlistMap['ganaparthimanishchowdary@gmail.com'] = {
    destinations: ['dest_munnar_01', 'dest_khajjiar_02'],
    agents: ['cdc23bc0-6b3c-4017-b3c5-38b37099bd23'],
    products: ['prod_cold_weather_sets']
  };

  // Format new subtitle preserving other syncs
  let before = '';
  let after = '';
  if (sub.includes('WISHLIST_SYNC:')) {
    before = sub.split('WISHLIST_SYNC:')[0].trim();
    let rest = sub.split('WISHLIST_SYNC:')[1].trim();
    for (const k of ['ORDERS_SYNC:', 'BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:']) {
      if (rest.includes(k)) {
        after = k + rest.split(k)[1];
        break;
      }
    }
  } else {
    before = sub;
  }

  const newSub = [before, `WISHLIST_SYNC:${JSON.stringify(wishlistMap)}`, after].filter(Boolean).join(' ').trim();

  const { error: uErr } = await supabase.from('banners').update({ subtitle: newSub }).eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985');
  console.log('Update result error:', uErr);

  // Read back
  const { data: checkData } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  console.log('Updated subtitle contains WISHLIST_SYNC:', checkData?.subtitle.includes('WISHLIST_SYNC:'));
}

testWishlistCentralSync();
