import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testNewOrder() {
  console.log('Authenticating session...');
  const { data: authData } = await supabase.auth.signInAnonymously();
  console.log('Authenticated User ID:', authData.user.id);

  const deliveryObj = {
    line1: '45 Silk Lane',
    line2: 'Suite 200',
    city: 'Bangalore',
    pincode: '560001',
    phone: '9876543210',
    name: 'Glossy Silk User',
    email: 'glossysilk@gmail.com',
    payment_method: 'UPI / QR (Instant)'
  };

  const { data, error } = await supabase.from('orders').insert({
    traveller_id: authData.user.id,
    items: [{ name: 'Silk Backpack', qty: 1, price: 1499 }],
    total_amount: 1499,
    status: 'placed',
    delivery_address: JSON.stringify(deliveryObj)
  }).select();

  if (error) {
    console.error('Order placement failed:', error);
  } else {
    console.log('Order placed successfully! Data:', data);
  }
}

testNewOrder();
