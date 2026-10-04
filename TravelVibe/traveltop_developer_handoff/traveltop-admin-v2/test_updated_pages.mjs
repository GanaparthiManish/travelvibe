import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testUpdatedLogic() {
  console.log('=== TESTING UPDATED USERS & ORDERS LOGIC ===\n');

  // --- USERS LOGIC TEST ---
  console.log('1. USERS PAGE LOGIC TEST:');
  let travellersMap = new Map();

  const { data: pData } = await supabase.from('profiles').select('*');
  (pData || []).filter(p => p.role !== 'agent').forEach(p => {
    travellersMap.set(p.email || p.id, {
      ...p,
      role: 'traveller',
    });
  });

  const { data: bData } = await supabase.from('banners').select('subtitle').eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985').maybeSingle();
  const sub = bData?.subtitle || '';

  const syncKeys = ['ORDERS_SYNC:', 'BOOKINGS_SYNC:', 'CATALOG_SYNC:', 'POLICY_SYNC:', 'WISHLIST_SYNC:'];

  if (sub.includes('ORDERS_SYNC:')) {
    let oStr = sub.split('ORDERS_SYNC:')[1].trim();
    for (const k of syncKeys) {
      if (k !== 'ORDERS_SYNC:') {
        if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
        if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
      }
    }
    try {
      const orders = JSON.parse(oStr);
      orders.forEach(o => {
        const email = o.traveller_email || (o.traveller_id?.includes('@') ? o.traveller_id : null);
        const key = email || o.traveller_id;
        if (key && !travellersMap.has(key)) {
          travellersMap.set(key, {
            id: o.traveller_id || key,
            full_name: o.traveller_name || (email ? email.split('@')[0] : 'Traveler User'),
            email: email || 'traveller@travelvibe.com',
            phone: o.delivery_address?.phone || '+91 98765 43210',
            role: 'traveller',
            suspended: false,
            photo_url: '',
            created_at: o.created_at || new Date().toISOString(),
          });
        }
      });
    } catch (e) {
      console.warn('Orders sync parse notice:', e.message);
    }
  }

  if (sub.includes('BOOKINGS_SYNC:')) {
    let bStr = sub.split('BOOKINGS_SYNC:')[1].trim();
    for (const k of syncKeys) {
      if (k !== 'BOOKINGS_SYNC:') {
        if (bStr.includes(' ' + k)) bStr = bStr.split(' ' + k)[0].trim();
        if (bStr.includes(k)) bStr = bStr.split(k)[0].trim();
      }
    }
    try {
      const bookings = JSON.parse(bStr);
      bookings.forEach(b => {
        const email = b.traveller_email || (b.traveller_id?.includes('@') ? b.traveller_id : null);
        const key = email || b.traveller_id;
        if (key && !travellersMap.has(key)) {
          travellersMap.set(key, {
            id: b.traveller_id || key,
            full_name: b.traveller_name || (email ? email.split('@')[0] : 'Traveler User'),
            email: email || 'traveller@travelvibe.com',
            phone: '+91 98765 43210',
            role: 'traveller',
            suspended: false,
            photo_url: '',
            created_at: b.created_at || new Date().toISOString(),
          });
        }
      });
    } catch (e) {
      console.warn('Bookings sync parse notice:', e.message);
    }
  }

  const catalog = Array.from(travellersMap.values());
  console.log(`Users catalog count = ${catalog.length}`);
  catalog.forEach(u => console.log(`  - User: ${u.full_name} | Email: ${u.email} | Phone: ${u.phone}`));

  // --- ORDERS LOGIC TEST ---
  console.log('\n2. ORDERS PAGE LOGIC TEST:');
  let dbOrders = [];
  const { data: oData } = await supabase.from('orders').select('*');
  if (oData) dbOrders = oData;

  let bannerOrders = [];
  if (sub.includes('ORDERS_SYNC:')) {
    let oStr = sub.split('ORDERS_SYNC:')[1].trim();
    for (const k of syncKeys) {
      if (k !== 'ORDERS_SYNC:') {
        if (oStr.includes(' ' + k)) oStr = oStr.split(' ' + k)[0].trim();
        if (oStr.includes(k)) oStr = oStr.split(k)[0].trim();
      }
    }
    try {
      bannerOrders = JSON.parse(oStr);
    } catch (e) {
      console.warn('Banner orders parse notice:', e.message);
    }
  }

  const allOrders = [...dbOrders];
  for (const bo of bannerOrders) {
    if (!allOrders.some(o => o.id === bo.id)) {
      allOrders.push(bo);
    }
  }

  console.log(`Orders catalog count = ${allOrders.length}`);
  allOrders.forEach(o => console.log(`  - Order #${o.id} | Traveller: ${o.traveller_name || o.traveller_email} | Total: ₹${o.total_amount || o.total} | Status: ${o.status}`));
}

testUpdatedLogic();
