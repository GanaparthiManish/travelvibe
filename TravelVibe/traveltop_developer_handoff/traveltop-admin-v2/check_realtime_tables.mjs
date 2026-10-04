import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function checkRealtime() {
  const { data, error } = await supabase.rpc('get_realtime_tables'); // or test table inserts
  console.log('Testing Realtime Subscriptions...');
  
  const tables = ['bookings', 'orders', 'messages', 'notifications', 'agent_details'];
  for (const t of tables) {
    const ch = supabase.channel(`check_${t}_${Date.now()}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: t }, (p) => {
        console.log(`Realtime active on table [${t}]: event = ${p.eventType}`);
      })
      .subscribe((status) => {
        console.log(`Table [${t}] subscription status: ${status}`);
      });
  }
  
  await new Promise(r => setTimeout(r, 4000));
}

checkRealtime();
