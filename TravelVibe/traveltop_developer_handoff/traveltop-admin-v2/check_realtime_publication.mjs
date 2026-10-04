import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkRealtimePublication() {
  console.log('=== REALTIME PUBLICATION CHECK ===\n');
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Test Realtime channel subscription for bookings and orders
  console.log('Testing Realtime Channel for bookings...');
  const ch1 = supabase.channel('realtime_check_bookings')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, (p) => {
      console.log('Realtime event received on bookings:', p);
    })
    .subscribe((status, err) => {
      console.log('Bookings Realtime Subscription Status:', status, err ? `Error: ${JSON.stringify(err)}` : '');
    });

  console.log('Testing Realtime Channel for orders...');
  const ch2 = supabase.channel('realtime_check_orders')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, (p) => {
      console.log('Realtime event received on orders:', p);
    })
    .subscribe((status, err) => {
      console.log('Orders Realtime Subscription Status:', status, err ? `Error: ${JSON.stringify(err)}` : '');
    });

  await new Promise(r => setTimeout(r, 3000));
  supabase.removeChannel(ch1);
  supabase.removeChannel(ch2);
}

checkRealtimePublication();
