import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function test() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  const { data: dests, error: dErr } = await supabase.from('destinations').select('id, name');
  console.log('All Destinations:', dests);

  for (const d of dests || []) {
    const { data: places, error: pErr } = await supabase.from('places').select('*, place_images(*)').eq('destination_id', d.id);
    console.log(`Destination "${d.name}" (${d.id}):`, places?.length, 'places found. Error:', pErr);
    if (places && places.length > 0) {
      console.log('  Places:', places.map(p => ({ id: p.id, name: p.name, images: p.place_images })));
    }
  }
}

test();
