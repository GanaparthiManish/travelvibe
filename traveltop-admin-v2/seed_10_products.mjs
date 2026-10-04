import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function seedProducts() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const products = [
    {
      name: 'Waterproof 45L Trekking Backpack',
      description: 'Ergonomic all-weather hiking and travel backpack with rain cover & laptop compartment.',
      price: 2999,
      image_url: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
      category: 'Backpacks',
      stock: 50,
      rating: 4.9
    },
    {
      name: 'Insulated Thermal Water Bottle (1L)',
      description: 'Double-wall vacuum insulated stainless steel flask keeps drinks ice-cold for 24h.',
      price: 799,
      image_url: 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
      category: 'Bottles',
      stock: 100,
      rating: 4.8
    },
    {
      name: 'Memory Foam Travel Neck Pillow',
      description: '360-degree head and neck support pillow with breathable washable velour cover.',
      price: 649,
      image_url: 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=600&q=80',
      category: 'Comfort',
      stock: 75,
      rating: 4.7
    },
    {
      name: 'Fast Charge 20,000mAh Power Bank',
      description: 'Ultra-high capacity portable charger with 22.5W Fast Delivery & LED display.',
      price: 1499,
      image_url: 'https://images.unsplash.com/photo-1609592807987-a2f004383492?auto=format&fit=crop&w=600&q=80',
      category: 'Electronics',
      stock: 60,
      rating: 4.9
    },
    {
      name: 'Universal All-in-One Travel Adapter',
      description: 'Global AC plug adapter supporting 150+ countries with 4 USB ports & Type-C fast charge.',
      price: 899,
      image_url: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?auto=format&fit=crop&w=600&q=80',
      category: 'Electronics',
      stock: 80,
      rating: 4.8
    },
    {
      name: 'Compression Travel Packing Cubes (Set of 6)',
      description: 'Expandable luggage organizer bags with heavy duty mesh & double zippers.',
      price: 999,
      image_url: 'https://images.unsplash.com/photo-1581553680321-4fffae59fccd?auto=format&fit=crop&w=600&q=80',
      category: 'Backpacks',
      stock: 40,
      rating: 4.7
    },
    {
      name: 'Quick-Dry Microfiber Camping Towel',
      description: 'Ultra-absorbent, lightweight, compact travel towel with hanging snap loop.',
      price: 499,
      image_url: 'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=600&q=80',
      category: 'Camping',
      stock: 120,
      rating: 4.6
    },
    {
      name: 'Compact Tactical Travel First Aid Kit',
      description: '100-piece waterproof medical emergency kit for hiking, camping, and road trips.',
      price: 599,
      image_url: 'https://images.unsplash.com/photo-1603398938378-e54eab446dde?auto=format&fit=crop&w=600&q=80',
      category: 'Camping',
      stock: 90,
      rating: 4.9
    },
    {
      name: 'Noise-Cancelling Travel Wireless Earbuds',
      description: 'Active Noise Cancellation Bluetooth 5.3 earbuds with 32h total playtime & mic.',
      price: 2499,
      image_url: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=600&q=80',
      category: 'Electronics',
      stock: 45,
      rating: 4.8
    },
    {
      name: 'TSA Approved Zinc Alloy Luggage Locks (2 Pack)',
      description: 'Heavy duty 3-digit combination padlocks for suitcases, backpacks, and duffels.',
      price: 399,
      image_url: 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=600&q=80',
      category: 'Comfort',
      stock: 150,
      rating: 4.7
    }
  ];

  // Delete existing products to avoid duplicates
  await supabase.from('products').delete().neq('id', '00000000-0000-0000-0000-000000000000');

  const { data, error } = await supabase.from('products').insert(products).select();
  console.log('Inserted products count:', data?.length, error);
}

seedProducts();
