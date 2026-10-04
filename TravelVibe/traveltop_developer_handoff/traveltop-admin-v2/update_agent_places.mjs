import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function updatePlaces() {
  const { error } = await supabase.from('agent_details').update({
    places_covered: ['Khajjiar', 'Munnar', 'Dalhousie', 'Himachal Trek'],
  }).eq('id', 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23');

  console.log('Places updated:', error || 'SUCCESS');
}

updatePlaces();
