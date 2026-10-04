import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://imretkikrsdydreldosx.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw'
);

async function verify() {
  console.log('--- Checking Supabase Database Tables ---');
  
  const { data: dests, error: e1 } = await supabase.from('destinations').select('*');
  console.log('Destinations count:', dests?.length || 0, 'Error:', e1?.message || 'none');
  if (dests && dests.length > 0) {
    console.log('Sample Destination:', dests[0]);
  }

  const { data: agents, error: e2 } = await supabase.from('agent_details').select('*, profiles!inner(full_name, photo_url, phone)');
  console.log('Agent Details count:', agents?.length || 0, 'Error:', e2?.message || 'none');
  if (agents && agents.length > 0) {
    console.log('Sample Agent:', agents[0].profiles?.full_name, 'Verified:', agents[0].verified, 'Price:', agents[0].price_per_day);
  }

  const { data: bookings, error: e3 } = await supabase.from('bookings').select('*');
  console.log('Bookings count:', bookings?.length || 0, 'Error:', e3?.message || 'none');

  const { data: prods, error: e4 } = await supabase.from('products').select('*');
  console.log('Products count:', prods?.length || 0, 'Error:', e4?.message || 'none');
}

verify();
