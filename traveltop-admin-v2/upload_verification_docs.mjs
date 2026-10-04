import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function uploadDocs() {
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Minimal 1x1 transparent JPEG byte buffer
  const sampleBuffer = Buffer.from('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=', 'base64');

  const { data: d1, error: e1 } = await supabase.storage.from('verification-docs').upload('sample_id_proof.jpg', sampleBuffer, { upsert: true, contentType: 'image/jpeg' });
  console.log('Uploaded sample_id_proof.jpg:', d1, 'Error:', e1?.message);

  const { data: d2, error: e2 } = await supabase.storage.from('verification-docs').upload('sample_selfie.jpg', sampleBuffer, { upsert: true, contentType: 'image/jpeg' });
  console.log('Uploaded sample_selfie.jpg:', d2, 'Error:', e2?.message);

  // Verify Signed URL generation
  const { data: s1, error: se1 } = await supabase.storage.from('verification-docs').createSignedUrl('sample_id_proof.jpg', 3600);
  console.log('Signed URL ID Proof:', s1?.signedUrl, 'Error:', se1?.message);
}

uploadDocs();
