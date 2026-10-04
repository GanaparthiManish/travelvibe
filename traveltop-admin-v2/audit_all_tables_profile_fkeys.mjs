import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const LEGACY_MAP = [
  {
    name: 'ganaparthimanishchowdary@gmail.com',
    oldId: 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    newId: 'cea15235-5af5-4c82-893f-c88d6ada8d20'
  },
  {
    name: 'ganaparthimanish@gmail.com',
    oldId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    newId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'
  },
  {
    name: 'ecomartx1@gmail.com',
    oldId: '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07',
    newId: '3b3cec91-9429-4ae2-b3b7-a1c5bbeaba07'
  }
];

async function auditAllProfileTables() {
  console.log('====================================================');
  console.log('   FULL PUBLIC SCHEMA PROFILE REFERENCES AUDIT     ');
  console.log('====================================================\n');

  const targets = [
    { table: 'orders', cols: ['traveller_id'] },
    { table: 'bookings', cols: ['traveller_id', 'agent_id'] },
    { table: 'wishlists', cols: ['traveller_id', 'agent_id'] },
    { table: 'messages', cols: ['sender_id'] },
    { table: 'reviews', cols: ['traveller_id', 'agent_id'] },
    { table: 'availability', cols: ['agent_id'] },
    { table: 'agent_addons', cols: ['agent_id'] }
  ];

  for (const acc of LEGACY_MAP) {
    console.log(`\n--- AUDITING ACCOUNT: ${acc.name} ---`);
    console.log(`    Old ID: ${acc.oldId} | New ID: ${acc.newId}`);

    for (const t of targets) {
      for (const col of t.cols) {
        // Query Old ID count
        try {
          const { count: oldCount } = await supabase.from(t.table).select('*', { count: 'exact', head: true }).eq(col, acc.oldId);
          const { count: newCount } = await supabase.from(t.table).select('*', { count: 'exact', head: true }).eq(col, acc.newId);

          console.log(`  Table [${t.table}.${col}]:`);
          console.log(`    - Old ID (${acc.oldId}): ${oldCount ?? 0}`);
          console.log(`    - New ID (${acc.newId}): ${newCount ?? 0}`);

          // Migrate if old rows exist and newId is different
          if (acc.oldId !== acc.newId && (oldCount ?? 0) > 0) {
            console.log(`    ⚡ Migrating ${oldCount} rows in ${t.table}.${col}...`);
            const updateObj = {};
            updateObj[col] = acc.newId;
            const { data: migData, error: migErr } = await supabase.from(t.table).update(updateObj).eq(col, acc.oldId).select();
            if (migErr) console.error(`    ❌ Migration Error: ${migErr.message}`);
            else console.log(`    ✅ Migrated ${migData ? migData.length : 0} rows successfully!`);
          }
        } catch (e) {
          console.log(`  Notice checking ${t.table}.${col}:`, e.message || e);
        }
      }
    }
  }

  console.log('\n====================================================');
  console.log('   FULL SCHEMA AUDIT & MIGRATION COMPLETED         ');
  console.log('====================================================');
}

auditAllProfileTables();
