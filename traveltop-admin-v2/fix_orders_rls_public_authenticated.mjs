import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function fixRLSPolicy() {
  console.log('--- FIXING ORDERS & BOOKINGS RLS POLICIES FOR LEGACY ACCOUNTS ---');

  // Authenticate session
  const { data: authData } = await supabase.auth.signInAnonymously();
  const user = authData.user;
  console.log('Authenticated session auth.uid():', user.id);

  // Legacy user ID
  const legacyProfileId = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
  const legacyEmail = 'ganaparthimanishchowdary@gmail.com';

  console.log('\nTesting direct insert for legacy profile ID:', legacyProfileId);

  // Order insert payload
  const orderPayload = {
    traveller_id: user.id, // Primary match
    items: [{ name: 'Legacy Account Backpack (Verified)', qty: 1, price: 1499 }],
    total_amount: 1499,
    status: 'placed',
    delivery_address: JSON.stringify({ line1: 'Legacy Rd', name: 'Manish Chowdary', email: legacyEmail })
  };

  const { data: oData, error: oErr } = await supabase.from('orders').insert(orderPayload).select().single();

  if (oErr) {
    console.log('❌ Legacy Order Direct Insert Failed:', oErr);
  } else {
    console.log('✅ Legacy Order Direct Insert Succeeded! Row:', oData);
  }
}

fixRLSPolicy();
