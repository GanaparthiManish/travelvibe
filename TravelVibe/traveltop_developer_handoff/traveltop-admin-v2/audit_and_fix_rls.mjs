import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function auditDatabase() {
  console.log('--- 1. Testing Table Access & RLS Policies ---');

  const tables = ['profiles', 'orders', 'bookings', 'products', 'banners', 'wishlists'];

  for (const table of tables) {
    try {
      const { data, error } = await supabase.from(table).select('*').limit(1);
      if (error) {
        console.log(`❌ Table [${table}] SELECT error:`, error.message, `(Code: ${error.code})`);
      } else {
        console.log(`✅ Table [${table}] SELECT success! Row count sample:`, data.length);
      }
    } catch (e) {
      console.log(`❌ Table [${table}] Exception:`, e);
    }
  }

  console.log('\n--- 3. Verifying Active URL and Keys ---');
  console.log('Active Supabase URL:', SUPABASE_URL);
  console.log('Project Ref:', 'imretkikrsdydreldosx');
}

auditDatabase();
