import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function syncAdminCatalog() {
  console.log('Syncing Admin Products to banners table CATALOG_SYNC and products table...');

  const adminProducts = [
    {
      id: 'prod_bag',
      name: 'bag',
      price: 1,
      stock: 10,
      rating: 4.8,
      category: 'Bags & Luggage',
      image_url: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      description: 'Compact lightweight travel bag.'
    },
    {
      id: 'prod_cold_weather_sets',
      name: 'Cold Weather Sets',
      price: 150,
      stock: 50,
      rating: 4.9,
      category: 'Clothing',
      image_url: 'https://images.unsplash.com/photo-1510312305653-8ed496efae75?auto=format&fit=crop&w=600&q=80',
      description: 'Thermal winter hiking and outdoor gear set.'
    },
    {
      id: 'prod_travel_backpack',
      name: 'Travel Backpack',
      price: 670,
      stock: 45,
      rating: 4.8,
      category: 'Bags & Luggage',
      image_url: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      description: 'Ergonomic all-weather hiking backpack.'
    },
    {
      id: 'prod_water_bottle',
      name: 'Insulated Thermal Water Bottle (1L)',
      price: 799,
      stock: 100,
      rating: 4.8,
      category: 'Hydration',
      image_url: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
      description: 'Double-wall vacuum insulated stainless steel water bottle.'
    },
    {
      id: 'prod_power_bank',
      name: 'Fast Charge 20,000mAh Power Bank',
      price: 1499,
      stock: 60,
      rating: 4.9,
      category: 'Electronics',
      image_url: 'https://images.unsplash.com/photo-1609592424109-dd9892f1b177?auto=format&fit=crop&w=600&q=80',
      description: 'Ultra-high capacity portable charger with fast charge dual output.'
    },
    {
      id: 'prod_travel_adapter',
      name: 'Universal All-in-One Travel Adapter',
      price: 899,
      stock: 80,
      rating: 4.8,
      category: 'Electronics',
      image_url: 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=600&q=80',
      description: 'Global AC plug adapter supporting 150+ countries with 4 USB ports.'
    }
  ];

  // 1. Update banners CATALOG_SYNC
  const { data: bData } = await supabase
    .from('banners')
    .select('subtitle')
    .eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985')
    .maybeSingle();

  let sub = bData?.subtitle || '';
  if (sub.includes('CATALOG_SYNC:')) {
    let before = sub.split('CATALOG_SYNC:')[0];
    let after = sub.split('CATALOG_SYNC:')[1];
    for (const k of ['WISHLIST_SYNC:', 'BOOKINGS_SYNC:', 'ORDERS_SYNC:', 'POLICY_SYNC:']) {
      if (after.includes(' ' + k)) after = ' ' + k + after.split(' ' + k)[1];
      else if (after.includes(k)) after = k + after.split(k)[1];
    }
    if (after.startsWith('[{') || after.startsWith('[')) after = '';
    sub = (before + ' ' + after).trim();
  }

  const newSub = (sub ? sub + ' ' : '') + 'CATALOG_SYNC:' + JSON.stringify(adminProducts);
  const { error: bErr } = await supabase
    .from('banners')
    .update({ subtitle: newSub })
    .eq('id', 'e4ca8130-72cf-4e17-bf47-47a623720985');

  if (bErr) {
    console.error('Banner catalog update failed:', bErr);
  } else {
    console.log('Banners CATALOG_SYNC updated successfully with all 6 products!');
  }
}

syncAdminCatalog();
