import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function check() {
  console.log('--- CHECKING 5-FEATURE SCHEMA READINESS ---');
  
  // 1. app_settings
  const { data: sData, error: sErr } = await supabase.from('app_settings').select('*').limit(2);
  console.log('1. app_settings:', sErr ? `❌ ${sErr.message}` : `✅ Found ${sData?.length} rows`);

  // 2. agent_details.specialization_tags
  const { data: aData, error: aErr } = await supabase.from('agent_details').select('id, specialization_tags').limit(1);
  console.log('2. agent_details.specialization_tags:', aErr ? `❌ ${aErr.message}` : `✅ Column exists`);

  // 3. guide_stories
  const { data: gData, error: gErr } = await supabase.from('guide_stories').select('*').limit(1);
  console.log('3. guide_stories:', gErr ? `❌ ${gErr.message}` : `✅ Table exists`);

  // 4. loyalty_rewards
  const { data: lData, error: lErr } = await supabase.from('loyalty_rewards').select('*').limit(1);
  console.log('4. loyalty_rewards:', lErr ? `❌ ${lErr.message}` : `✅ Table exists`);

  // 5. profiles referral_code
  const { data: pData, error: pErr } = await supabase.from('profiles').select('id, referral_code, referred_by').limit(1);
  console.log('5. profiles referral columns:', pErr ? `❌ ${pErr.message}` : `✅ Columns exist`);

  // 6. bookings group_size
  const { data: bData, error: bErr } = await supabase.from('bookings').select('id, group_size, group_members').limit(1);
  console.log('6. bookings group columns:', bErr ? `❌ ${bErr.message}` : `✅ Columns exist`);

  // 7. agent_addons
  const { data: adData, error: adErr } = await supabase.from('agent_addons').select('*').limit(1);
  console.log('7. agent_addons:', adErr ? `❌ ${adErr.message}` : `✅ Table exists`);
}

check();
