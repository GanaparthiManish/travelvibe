import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function seedBanners() {
  console.log('=== SEEDING ADMIN PROMOTIONAL BANNERS ===');

  const banners = [
    {
      title: 'Get 25% OFF Your First Local Guide!',
      subtitle: 'Book verified local experts in Khajjiar & Munnar with code GUIDE25.',
      badge_text: 'FLAT 25% OFF',
      banner_type: 'agent_discount',
      image_url: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80',
      display_order: 1,
      is_active: true,
    },
    {
      title: 'Essential Trekking & Outdoor Gear',
      subtitle: 'High-performance backpacks, boots & jackets with free express delivery.',
      badge_text: 'GEAR STORE',
      banner_type: 'shop_item',
      image_url: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=1200&q=80',
      display_order: 2,
      is_active: true,
    },
  ];

  try {
    await supabase.from('banners').delete().neq('id', '00000000-0000-0000-0000-000000000000');
    const { data, error } = await supabase.from('banners').insert(banners).select();
    console.log('Banners inserted:', data?.length, error || 'SUCCESS');
  } catch (e) {
    console.error('Error seeding banners:', e);
  }
}

seedBanners();
