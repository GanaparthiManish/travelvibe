import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function alterOrdersTable() {
  console.log('Logging in as Admin to execute ALTER TABLE orders...');
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Admin Auth Failed:', authErr);
    return;
  }

  console.log('Admin Auth Succeeded! Executing schema updates...');

  // We can test inserting an order with all fields to see which columns exist!
  const testPayload = {
    traveller_id: authData.user.id,
    traveller_name: 'Manish Ganaparthi',
    traveller_email: 'ganaparthimanish@gmail.com',
    items: [{ name: 'Travel Bag', qty: 1, price: 1 }],
    total_amount: 1,
    status: 'placed',
    payment_method: 'UPI / QR (Instant)',
    payment_status: 'Paid',
    delivery_address: {
      line1: '123 Main Street',
      city: 'Ooty',
      pincode: '643001',
      phone: '9876543210'
    }
  };

  const { data, error } = await supabase.from('orders').insert(testPayload).select();

  if (error) {
    console.error('Insert with all fields failed:', error);
  } else {
    console.log('Insert with all fields SUCCEEDED!', data);
  }
}

alterOrdersTable();
