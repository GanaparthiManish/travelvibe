import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function inspectColumns() {
  const { data, error } = await supabase.rpc('execute_sql_query', {
    query_text: "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'support_tickets';"
  });

  if (error) {
    console.log('RPC error, checking via select fallback...');
    const { data: selectData, error: sErr } = await supabase.from('support_tickets').select('*').limit(0);
    console.log('Select error:', sErr);
  } else {
    console.log('Columns of support_tickets:', data);
  }
}

inspectColumns();
