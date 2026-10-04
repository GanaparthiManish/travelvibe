import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function test() {
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Try querying pg_proc
  const { data: procData, error: procErr } = await supabase.from('pg_proc').select('proname').limit(20);
  console.log('pg_proc:', procErr ? procErr.message : procData);

  // Try common custom function names
  const testFns = [
    'exec_sql', 'execute_sql', 'run_sql', 'exec_query', 'run_query',
    'admin_exec', 'pg_exec', 'sql_exec', 'query_exec', 'apply_migration'
  ];

  for (const fn of testFns) {
    const { data, error } = await supabase.rpc(fn, { sql: 'SELECT 1;' });
    if (!error || !error.message.includes('Could not find')) {
      console.log(`FOUND RPC ${fn}:`, error ? error.message : data);
    }
  }
}

test();
