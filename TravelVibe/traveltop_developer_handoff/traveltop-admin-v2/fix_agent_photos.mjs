import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function fixAgentPhotos() {
  const manishId = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
  const workingPhotoUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80';

  // 1. Update profiles table for Manish
  const { data: pData, error: pErr } = await supabase
    .from('profiles')
    .update({ photo_url: workingPhotoUrl })
    .eq('id', manishId)
    .select();
  console.log('Profiles update:', pData, pErr);

  // 2. Update agent_details table for Manish
  const { data: aData, error: aErr } = await supabase
    .from('agent_details')
    .update({ selfie_url: workingPhotoUrl })
    .eq('id', manishId)
    .select();
  console.log('Agent details update:', aData, aErr);

  // 3. Update all profiles where photo_url is null or points to broken link
  const { data: allProfiles } = await supabase.from('profiles').select('id, full_name, photo_url');
  if (allProfiles) {
    for (const prof of allProfiles) {
      if (!prof.photo_url || prof.photo_url.includes('1787149064928')) {
        await supabase
          .from('profiles')
          .update({ photo_url: workingPhotoUrl })
          .eq('id', prof.id);
        console.log('Fixed photo for:', prof.full_name, prof.id);
      }
    }
  }
}

fixAgentPhotos();
