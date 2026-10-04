import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testMergedBookings() {
  console.log('--- Testing Merged Bookings in Bookings.jsx ---');

  // 1. Fetch DB bookings
  let supaRows = [];
  try {
    const { data } = await supabase.from('bookings').select(`*, profiles!traveller_id(full_name), agent_details!agent_id(profiles(full_name))`);
    if (data) supaRows = data;
  } catch (e) {
    console.error('DB fetch error:', e);
  }

  // 2. Fetch Banner bookings
  let bannerRows = [];
  const { data: bRes } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  const sub = bRes?.subtitle || '';
  if (sub.includes('BOOKINGS_SYNC:')) {
    let afterKey = sub.split('BOOKINGS_SYNC:')[1].trim();
    for (const k of ['ORDERS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (afterKey.includes(' ' + k)) afterKey = afterKey.split(' ' + k)[0].trim();
      if (afterKey.includes(k)) afterKey = afterKey.split(k)[0].trim();
    }
    const parsed = JSON.parse(afterKey);
    bannerRows = (parsed || []).map(b => ({
      ...b,
      destination: b.destination || 'Custom Trek & Tour Package',
      profiles: { full_name: b.traveller_name || b.traveller_id },
      agent_details: { profiles: { full_name: b.agent_name } },
      _fromBanners: true,
    }));
  }

  const supaIds = new Set(supaRows.map(r => r.id));
  const merged = [
    ...supaRows,
    ...bannerRows.filter(b => !supaIds.has(b.id)),
  ];

  console.log(`Merged Bookings Count: ${merged.length}`);
  merged.forEach(b => console.log(`  - Booking #${b.id} | Traveller: ${b.profiles?.full_name || b.traveller_id} | Agent: ${b.agent_details?.profiles?.full_name || b.agent_name || b.agent_id} | Total: ₹${b.total_price} | Status: ${b.status}`));
}

testMergedBookings();
