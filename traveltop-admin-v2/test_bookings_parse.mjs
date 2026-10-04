import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testBookingsParse() {
  console.log('--- Testing Bookings Parsing ---');
  const { data: bRes } = await supabase
    .from('banners')
    .select('subtitle')
    .eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985')
    .maybeSingle();

  const sub = bRes?.subtitle || '';
  console.log('Sub contains BOOKINGS_SYNC:', sub.includes('BOOKINGS_SYNC:'));

  if (sub.includes('BOOKINGS_SYNC:')) {
    let afterKey = sub.split('BOOKINGS_SYNC:')[1].trim();
    for (const k of ['ORDERS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:']) {
      if (afterKey.includes(' ' + k)) afterKey = afterKey.split(' ' + k)[0].trim();
      if (afterKey.includes(k)) afterKey = afterKey.split(k)[0].trim();
    }
    try {
      const parsed = JSON.parse(afterKey);
      console.log('Successfully parsed BOOKINGS_SYNC count:', parsed.length);
      console.log('Bookings:', parsed);
    } catch (e) {
      console.error('JSON parse error:', e.message);
    }
  }
}

testBookingsParse();
