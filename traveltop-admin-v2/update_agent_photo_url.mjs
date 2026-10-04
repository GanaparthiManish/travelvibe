import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function updatePhoto() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const agentId = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
  const selfiePath = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23/1787149064928_IMG_20260815_164826985.jpg';
  const publicPhotoUrl = `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${selfiePath}`;

  const { data: pData, error: pErr } = await supabase
    .from('profiles')
    .update({ photo_url: publicPhotoUrl, full_name: 'Ganaparthi manish' })
    .eq('id', agentId)
    .select();

  console.log('Updated profile photo:', pData, pErr);

  const { data: aData, error: aErr } = await supabase
    .from('agent_details')
    .update({
      verification_status: 'approved',
      verified: true
    })
    .eq('id', agentId)
    .select();

  console.log('Updated agent details status:', aData, aErr);
}

updatePhoto();
