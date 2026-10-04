import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function restoreAllRealOrders() {
  console.log('=== RESTORING ALL REAL USER ORDERS IN CENTRAL STORE ===\n');

  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Real Orders List (Both Ganaparthi Manish and Eco MartX)
  const realOrders = [
    {
      id: 'TV-ORD-4135564',
      traveller_id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      traveller_name: 'Ganaparthi Manish chowdary',
      traveller_email: 'ganaparthimanishchowdary@gmail.com',
      total_amount: 1,
      status: 'placed',
      payment_method: 'UPI',
      created_at: '2026-08-22T07:15:00.000Z',
      items: [{ product_id: 'prod_cold_weather_sets', name: 'Cold Weather Sets', qty: 1, price: 1 }]
    },
    {
      id: 'TV-ORD-8574034',
      traveller_id: 'ecomartx1@gmail.com',
      traveller_name: 'Eco MartX',
      traveller_email: 'ecomartx1@gmail.com',
      total_amount: 1,
      status: 'placed',
      payment_method: 'COD',
      created_at: '2026-08-22T08:00:00.000Z',
      items: [{ product_id: 'prod_bag', name: 'bag', qty: 1, price: 1 }]
    }
  ];

  const realWishlists = {
    'ganaparthimanishchowdary@gmail.com': {
      destinations: ['4f1047d2-474a-4c1f-9515-8764ac40ecba'],
      agents: [],
      products: []
    },
    'ecomartx1@gmail.com': {
      destinations: [],
      agents: [],
      products: []
    }
  };

  const cleanSubtitle = `ORDERS_SYNC:${JSON.stringify(realOrders)} WISHLIST_SYNC:${JSON.stringify(realWishlists)}`;

  const { data, error } = await supabase.from('banners')
    .update({ subtitle: cleanSubtitle })
    .eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985')
    .select();

  console.log('Restored all real orders:', error ? `Error: ${JSON.stringify(error)}` : 'SUCCESS ✓');
}

restoreAllRealOrders();
