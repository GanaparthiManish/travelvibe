import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function test() {
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const paramVariants = [
    { query: 'SELECT 1;' },
    { sql: 'SELECT 1;' },
    { query_string: 'SELECT 1;' },
    { sql_query: 'SELECT 1;' },
    { cmd: 'SELECT 1;' }
  ];

  for (const fn of ['exec_sql', 'execute_sql', 'run_sql', 'exec']) {
    for (const params of paramVariants) {
      const { data, error } = await supabase.rpc(fn, params);
      console.log(`RPC "${fn}" params ${Object.keys(params)[0]}:`, error ? error.message : data);
    }
  }
}

test();
