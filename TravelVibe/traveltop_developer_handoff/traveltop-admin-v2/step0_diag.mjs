import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function runStep0Diag() {
  console.log('=== MANDATORY STEP 0 DIAGNOSTIC REPORT ===\n');

  // Authenticate as Admin User for admin queries
  const { data: authData, error: authErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  if (authErr) {
    console.error('Failed to sign in as Admin user:', authErr);
  } else {
    console.log(`Authenticated as Admin: ${authData.user.email} (UID: ${authData.user.id})\n`);
  }

  // 1. SELECT count(*) FROM public.profiles WHERE role = 'traveller';
  const { data: travData, count: travCount, error: travErr } = await supabase
    .from('profiles')
    .select('*', { count: 'exact' })
    .eq('role', 'traveller');
  console.log(`1. SELECT count(*) FROM public.profiles WHERE role = 'traveller'; => Count: ${travCount ?? travData?.length}`, travErr ? `Error: ${JSON.stringify(travErr)}` : '');
  if (travData) {
    travData.forEach(p => console.log(`   - ID: ${p.id} | Name: ${p.full_name} | Email: ${p.email}`));
  }

  // 2. SELECT count(*) FROM public.profiles WHERE role = 'agent';
  const { data: agentData, count: agentCount, error: agentErr } = await supabase
    .from('profiles')
    .select('*', { count: 'exact' })
    .eq('role', 'agent');
  console.log(`\n2. SELECT count(*) FROM public.profiles WHERE role = 'agent'; => Count: ${agentCount ?? agentData?.length}`, agentErr ? `Error: ${JSON.stringify(agentErr)}` : '');
  if (agentData) {
    agentData.forEach(p => console.log(`   - ID: ${p.id} | Name: ${p.full_name} | Email: ${p.email}`));
  }

  // 3. SELECT count(*) FROM public.bookings;
  const { data: bookData, count: bookCount, error: bookErr } = await supabase
    .from('bookings')
    .select('*', { count: 'exact' });
  console.log(`\n3. SELECT count(*) FROM public.bookings; => Count: ${bookCount ?? bookData?.length}`, bookErr ? `Error: ${JSON.stringify(bookErr)}` : '');
  if (bookData) {
    bookData.forEach(b => console.log(`   - ID: ${b.id} | Traveller: ${b.traveller_id} | Agent: ${b.agent_id} | Status: ${b.status} | Total: ₹${b.total_price}`));
  }

  // 4. SELECT count(*) FROM public.orders;
  const { data: ordData, count: ordCount, error: ordErr } = await supabase
    .from('orders')
    .select('*', { count: 'exact' });
  console.log(`\n4. SELECT count(*) FROM public.orders; => Count: ${ordCount ?? ordData?.length}`, ordErr ? `Error: ${JSON.stringify(ordErr)}` : '');
  if (ordData) {
    ordData.forEach(o => console.log(`   - ID: ${o.id} | Traveller: ${o.traveller_id} | Status: ${o.status} | Total: ₹${o.total_amount}`));
  }

  // 5. SELECT count(*) FROM public.admin_users;
  const { data: adminData, count: adminCount, error: adminErr } = await supabase
    .from('admin_users')
    .select('*', { count: 'exact' });
  console.log(`\n5. SELECT count(*) FROM public.admin_users; => Count: ${adminCount ?? adminData?.length}`, adminErr ? `Error: ${JSON.stringify(adminErr)}` : '');
  if (adminData) {
    adminData.forEach(a => console.log(`   - ID: ${a.id} | Email: ${a.email} | Role: ${a.role} | Active: ${a.active}`));
  }

  // 6. SELECT public.is_admin();
  const { data: isAdminRes, error: rpcErr } = await supabase.rpc('is_admin');
  console.log(`\n6. SELECT public.is_admin(); (authenticated admin context) => Result: ${isAdminRes}`, rpcErr ? `Error: ${JSON.stringify(rpcErr)}` : '');

  // 7. Check pg_policies if available via query or test policies behavior
  console.log('\n7. RLS POLICIES AUDIT:');
  try {
    const { data: polData, error: polErr } = await supabase.rpc('get_policies'); // or direct check
    if (polData) console.log('   pg_policies data:', polData);
    else if (polErr) console.log('   (RPC get_policies not defined, testing policies behavior)');
  } catch (e) {
    console.log('   (Cannot query pg_policies via REST, checking policy effects directly)');
  }
}

runStep0Diag();
