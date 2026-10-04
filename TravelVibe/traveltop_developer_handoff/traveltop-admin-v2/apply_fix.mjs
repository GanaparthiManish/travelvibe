import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function applyFix() {
  console.log('=== APPLYING FIX FOR PROFILES AND ORDERS SYNC ===\n');

  // 1. Upsert missing traveller profile ecomartx1@gmail.com into profiles table
  console.log('1. Upserting missing profile for Eco MartX (ecomartx1@gmail.com)...');
  const { data: pData, error: pErr } = await supabase.from('profiles').upsert([
    {
      id: 'ecomartx1@gmail.com',
      full_name: 'Eco MartX',
      email: 'ecomartx1@gmail.com',
      phone: '+91 98765 43210',
      role: 'traveller',
      suspended: false,
      created_at: new Date().toISOString()
    },
    {
      id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
      full_name: 'Ganaparthi Manish chowdary',
      email: 'ganaparthimanishchowdary@gmail.com',
      phone: '+91 88978 68951',
      role: 'traveller',
      suspended: false,
      created_at: '2026-08-22T03:10:05.516176+00:00'
    }
  ]).select();

  console.log('Profile upsert result:', pData, 'Error:', pErr);

  // 2. Try inserting orders into database orders table (if id is text)
  console.log('\n2. Backfilling orders into orders table...');
  const { data: oData, error: oErr } = await supabase.from('orders').upsert([
    {
      id: 'TV-ORD-8574034',
      traveller_id: 'ecomartx1@gmail.com',
      total_amount: 769,
      status: 'packed',
      delivery_address: {
        line1: 'Flat 402, Royal Residency',
        line2: 'Jubilee Hills, Road No. 36',
        city: 'Hyderabad',
        pincode: '500033',
        phone: '+91 98765 43210'
      },
      created_at: '2026-08-22T03:12:54.034353'
    },
    {
      id: 'TV-ORD-8311601',
      traveller_id: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
      total_amount: 249,
      status: 'packed',
      delivery_address: {
        line1: 'Flat 402, Royal Residency',
        line2: 'Jubilee Hills, Road No. 36',
        city: 'Hyderabad',
        pincode: '500033',
        phone: '+91 98765 43210'
      },
      created_at: '2026-08-22T03:08:31.601645'
    }
  ]).select();

  console.log('Orders upsert result:', oData, 'Error:', oErr);
}

applyFix();
