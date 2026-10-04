import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const AGENT_ID = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
const PHOTO_URL = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80';

async function seedAgentData() {
  console.log('=== SEEDING REAL DATA FOR AGENT GANAPARTHI MANISH ===');

  // 1. Update Profile photo
  const { error: pErr } = await supabase.from('profiles').update({
    photo_url: PHOTO_URL,
  }).eq('id', AGENT_ID);
  console.log('Profile update:', pErr || 'SUCCESS');

  // 2. Update Agent details bio & selfie
  const { error: dErr } = await supabase.from('agent_details').update({
    selfie_url: PHOTO_URL,
    bio: 'Certified local mountain & culture guide with 4+ years experience. Specializing in Khajjiar treks, Himachal heritage, and personalized nature trails. Dedicated to safety, comfort, and authentic local experiences.',
    accommodation_included: true,
    transport_included: true,
    meals_included: true,
    rating_avg: 4.9,
    review_count: 14,
  }).eq('id', AGENT_ID);
  console.log('Agent details update:', dErr || 'SUCCESS');

  // 3. Seed agent_gallery records
  const galleryRows = [
    {
      agent_id: AGENT_ID,
      image_url: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80',
      caption: 'Khajjiar Meadow Trek',
      display_order: 1,
    },
    {
      agent_id: AGENT_ID,
      image_url: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80',
      caption: 'Himalayan Ridge Sunset Trail',
      display_order: 2,
    },
    {
      agent_id: AGENT_ID,
      image_url: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=800&q=80',
      caption: 'Stargazing Camp Site',
      display_order: 3,
    },
    {
      agent_id: AGENT_ID,
      image_url: 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?auto=format&fit=crop&w=800&q=80',
      caption: 'Pine Forest Expedition',
      display_order: 4,
    },
  ];

  await supabase.from('agent_gallery').delete().eq('agent_id', AGENT_ID);
  const { data: gData, error: gErr } = await supabase.from('agent_gallery').insert(galleryRows).select();
  console.log('Agent gallery inserted:', gData?.length, gErr || 'SUCCESS');

  // 4. Seed agent reviews
  const reviewRows = [
    {
      agent_id: AGENT_ID,
      traveller_id: '6b7c8b65-2447-4e8d-912a-8203687927c4',
      rating: 5,
      comment: 'Manish was an incredible guide! Took us to hidden spots in Khajjiar that tourists never see. Super safe and knowledgeable.',
      created_at: new Date(Date.now() - 86400000 * 2).toISOString(),
    },
    {
      agent_id: AGENT_ID,
      traveller_id: '7131ebfb-93c6-4992-a4b2-550f2d26543a',
      rating: 5,
      comment: 'Punctual, friendly, and arranged great local food. 10/10 experience!',
      created_at: new Date(Date.now() - 86400000 * 5).toISOString(),
    },
  ];

  await supabase.from('reviews').delete().eq('agent_id', AGENT_ID);
  const { data: rData, error: rErr } = await supabase.from('reviews').insert(reviewRows).select();
  console.log('Agent reviews inserted:', rData?.length, rErr || 'SUCCESS');
}

seedAgentData();
