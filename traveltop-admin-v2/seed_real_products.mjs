import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function seedProducts() {
  console.log('Logging in as Admin to seed clean real products...');
  const { data: authData } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });

  const products = [
    {
      name: 'Ergonomic Travel Backpack (45L)',
      category: 'Bags & Luggage',
      price: 1499,
      rating: 4.8,
      stock: 50,
      image_url: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      description: 'Water-resistant, lightweight 45L travel backpack with laptop compartment and rain cover.'
    },
    {
      name: 'Insulated Stainless Steel Water Bottle (1L)',
      category: 'Hydration',
      price: 799,
      rating: 4.9,
      stock: 100,
      image_url: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
      description: 'Keeps liquids cold for 24 hours and hot for 12 hours. BPA-free leakproof design.'
    },
    {
      name: 'Compact Thermal Sleeping Bag',
      category: 'Camping',
      price: 2499,
      rating: 4.7,
      stock: 30,
      image_url: 'https://images.unsplash.com/photo-1510312305653-8ed496efae75?auto=format&fit=crop&w=600&q=80',
      description: 'Ultralight cold-weather sleeping bag with compression sack for hiking and camping.'
    }
  ];

  const { data, error } = await supabase.from('products').insert(products).select();
  if (error) {
    console.error('Seed error:', error);
  } else {
    console.log('Seeded clean products successfully! IDs:', data.map(p => p.id));
  }
}

seedProducts();
