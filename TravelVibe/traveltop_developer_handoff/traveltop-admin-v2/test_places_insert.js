import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function test() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  
  // 1. Fetch first destination
  const { data: dests, error: dErr } = await supabase.from('destinations').select('id, name').limit(1);
  console.log('Destination fetch:', dests, dErr);

  if (!dests || !dests[0]) {
    console.log('No destination found');
    return;
  }

  const destId = dests[0].id;
  console.log('Testing place insert for destination:', destId, dests[0].name);

  // 2. Try inserting a place
  const { data: placeData, error: pErr } = await supabase.from('places').insert({
    destination_id: destId,
    name: 'Test Place Node ' + Date.now(),
    category: 'Nature',
    description: 'Test description',
    ideal_duration: '2 hours',
    best_time_of_day: 'Morning',
    display_order: 0
  }).select().single();

  console.log('Place insert result:', placeData, 'Error:', pErr);

  // 3. Try fetching places for this destination
  const { data: fetchP, error: fErr } = await supabase.from('places').select('*, place_images(*)').eq('destination_id', destId);
  console.log('Places fetch result:', fetchP, 'Error:', fErr);
}

test();
