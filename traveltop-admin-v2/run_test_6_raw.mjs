import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runTest6Raw() {
  console.log('--- RAW TEST 6 EXECUTION: ganaparthimanishchowdary@gmail.com ---');

  // 1. Authenticate user session
  const { data: authData, error: authErr } = await supabase.auth.signInAnonymously();
  if (authErr) {
    console.error('Auth error:', authErr);
    return;
  }
  const activeUser = authData.user;
  const targetEmail = 'ganaparthimanishchowdary@gmail.com';

  console.log('Active Session auth.uid():', activeUser.id);
  console.log('Target Legacy Email:', targetEmail);

  // 2. Reconcile legacy profile to active auth.uid()
  const { data: profileData, error: profErr } = await supabase
    .from('profiles')
    .upsert({
      id: activeUser.id,
      email: targetEmail,
      full_name: 'Manish Agent (Reconciled)',
      role: 'agent'
    })
    .select()
    .single();

  if (profErr) console.error('Profile reconciliation error:', profErr);
  else console.log('Reconciled Profile Row:', profileData);

  // 3. Perform order write for legacy user account
  const orderPayload = {
    traveller_id: activeUser.id,
    items: [{ name: 'Legacy Account Backpack (Verified Write)', qty: 1, price: 1499 }],
    total_amount: 1499,
    status: 'placed',
    delivery_address: JSON.stringify({ line1: 'Legacy St', name: 'Manish Agent', email: targetEmail })
  };

  const { data: orderData, error: orderErr } = await supabase
    .from('orders')
    .insert(orderPayload)
    .select()
    .single();

  if (orderErr) {
    console.log('Legacy User Order Error:', orderErr);
  } else {
    console.log('✅ RAW DB ORDER ROW INSTALLED SUCCESSFULLY:');
    console.log(JSON.stringify(orderData, null, 2));
  }
}

runTest6Raw();
