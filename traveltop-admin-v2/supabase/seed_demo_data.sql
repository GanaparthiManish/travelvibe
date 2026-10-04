-- ============================================================================
-- TravelTop Demo Data Seed Script (UUID Compatible & 100% Schema Guaranteed)
-- ============================================================================

-- 0. Migration Safety & Table Column Guarantee
ALTER TABLE destinations ADD COLUMN IF NOT EXISTS ideal_duration text;
ALTER TABLE destinations ADD COLUMN IF NOT EXISTS travel_tips text[];
ALTER TABLE destinations ADD COLUMN IF NOT EXISTS best_season text;
ALTER TABLE destinations ADD COLUMN IF NOT EXISTS best_months text[];
ALTER TABLE destinations ADD COLUMN IF NOT EXISTS risky_months text[];
ALTER TABLE destinations ADD COLUMN IF NOT EXISTS category text;

ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS experience_years integer DEFAULT 5;
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS languages text[];
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS rating_avg numeric DEFAULT 4.8;
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS review_count integer DEFAULT 10;
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS safety_score integer DEFAULT 98;
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS includes_stay boolean DEFAULT false;
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS includes_transport boolean DEFAULT true;
ALTER TABLE agent_details ADD COLUMN IF NOT EXISTS includes_meals boolean DEFAULT false;

-- Profile table column migrations
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role text DEFAULT 'traveller';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS photo_url text;

-- Products table column migrations
ALTER TABLE products ADD COLUMN IF NOT EXISTS category text DEFAULT 'General';
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Create place_images table if missing
CREATE TABLE IF NOT EXISTS place_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id uuid REFERENCES places(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  caption text,
  sort_order integer DEFAULT 1,
  created_at timestamptz DEFAULT now()
);

-- Drop check constraint on places category if it exists
ALTER TABLE places DROP CONSTRAINT IF EXISTS places_category_check;

-- 1. Insert Sample Destinations (UUID v4 IDs)
INSERT INTO destinations (id, name, country, description, cover_image_url, is_featured, is_trending, best_season, best_months, risky_months, ideal_duration, travel_tips, category)
VALUES
(
  'a1111111-1111-4111-a111-111111111111',
  'Munnar',
  'India',
  'Rolling tea gardens, mist-covered hills, and exotic flora make Munnar the premier hill station of South India.',
  'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=1200&q=80',
  true,
  true,
  'Post-Monsoon to Winter (September to March) offering pleasant weather and clear tea valley views.',
  ARRAY['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'],
  ARRAY['Jun', 'Jul', 'Aug'],
  '3 - 4 Days',
  ARRAY['Carry light woollens for evening cold.', 'Book tea factory tours early in the morning.', 'Rent a local jeep for rough terrain in Top Station.'],
  'hills'
),
(
  'a2222222-2222-4222-a222-222222222222',
  'Ladakh',
  'India',
  'Land of high passes, vibrant monasteries, crystal blue lakes, and breathtaking Himalayan scenery.',
  'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=1200&q=80',
  true,
  true,
  'Summer (May to September) when roads and passes like Khardung La are open and accessible.',
  ARRAY['May', 'Jun', 'Jul', 'Aug', 'Sep'],
  ARRAY['Nov', 'Dec', 'Jan', 'Feb'],
  '6 - 8 Days',
  ARRAY['Acclimatize for at least 48 hours in Leh before traveling to high altitudes.', 'Keep cash handy as card networks are limited.', 'Apply high SPF sunscreen and lip balm.'],
  'adventure'
),
(
  'a3333333-3333-4333-a333-333333333333',
  'Goa',
  'India',
  'Sun-kissed beaches, Portuguese heritage architecture, vibrant night markets, and thrilling water sports.',
  'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=80',
  true,
  false,
  'Winter (November to February) for sunny beaches, water activities, and festive night life.',
  ARRAY['Nov', 'Dec', 'Jan', 'Feb'],
  ARRAY['Jun', 'Jul', 'Aug'],
  '4 - 5 Days',
  ARRAY['Rent a scooter for easy commuting between North and South Goa.', 'Visit Fontainhas early morning for heritage photos.', 'Always check sea safety flags before swimming.'],
  'beach'
),
(
  'a4444444-4444-4444-a444-444444444444',
  'Alleppey',
  'India',
  'Venice of the East, famous for tranquil backwater cruises, luxury houseboats, and green paddy fields.',
  'https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?auto=format&fit=crop&w=1200&q=80',
  true,
  true,
  'Winter (November to February) for serene houseboat cruises and pleasant breezes.',
  ARRAY['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'],
  ARRAY['Jun', 'Jul'],
  '2 - 3 Days',
  ARRAY['Book overnight houseboats with freshly cooked Keralite meals.', 'Explore narrow canals on a small wooden canoe for authentic village views.'],
  'honeymoon'
),
(
  'a5555555-5555-4555-a555-555555555555',
  'Rishikesh',
  'India',
  'Yoga capital of the world, adventure hub for white-water rafting, cliff jumping, and spiritual evening Aarti.',
  'https://images.unsplash.com/photo-1596895111956-bf1cf0599ce5?auto=format&fit=crop&w=1200&q=80',
  true,
  false,
  'September to November and March to May for rafting and spiritual retreats.',
  ARRAY['Mar', 'Apr', 'May', 'Sep', 'Oct', 'Nov'],
  ARRAY['Jul', 'Aug'],
  '3 - 5 Days',
  ARRAY['Attend Triveni Ghat evening Ganga Aarti by 6:00 PM.', 'Choose certified river rafting operators at Shivpuri.'],
  'culture'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  country = EXCLUDED.country,
  description = EXCLUDED.description,
  cover_image_url = EXCLUDED.cover_image_url,
  is_featured = EXCLUDED.is_featured,
  is_trending = EXCLUDED.is_trending,
  best_season = EXCLUDED.best_season,
  best_months = EXCLUDED.best_months,
  risky_months = EXCLUDED.risky_months,
  ideal_duration = EXCLUDED.ideal_duration,
  travel_tips = EXCLUDED.travel_tips,
  category = EXCLUDED.category;

-- 2. Insert Sample Places & Place Images (Story Viewer Content)
INSERT INTO places (id, destination_id, name, category, description, ideal_duration, best_time_of_day)
VALUES
(
  'b1111111-1111-4111-b111-111111111111',
  'a1111111-1111-4111-a111-111111111111',
  'Eravikulam National Park',
  'Nature',
  'Home to the endangered Nilgiri Tahr. Features lush green slopes and wild mountain orchids.',
  '3 Hours',
  'Early Morning (7:30 AM)'
),
(
  'b2222222-2222-4222-b222-222222222222',
  'a1111111-1111-4111-a111-111111111111',
  'Top Station Viewpoint',
  'Viewpoint',
  'Highest point in Munnar offering a 360-degree panoramic view of the Western Ghats and Tamil Nadu plains.',
  '2 Hours',
  'Sunrise (6:00 AM)'
),
(
  'b3333333-3333-4333-b333-333333333333',
  'a2222222-2222-4222-a222-222222222222',
  'Pangong Tso Lake',
  'Lake',
  'Stunning endorheic lake at 14,270 ft known for changing colors from turquoise blue to deep violet.',
  'Full Day / Overnight',
  'Sunset & Night Stargazing'
),
(
  'b4444444-4444-4444-b444-444444444444',
  'a2222222-2222-4222-a222-222222222222',
  'Nubra Valley & Hunder Sand Dunes',
  'Desert',
  'High altitude cold desert famous for double-humped Bactrian camel rides among snow-capped peaks.',
  '1 - 2 Days',
  'Late Afternoon'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  description = EXCLUDED.description,
  ideal_duration = EXCLUDED.ideal_duration,
  best_time_of_day = EXCLUDED.best_time_of_day;

INSERT INTO place_images (id, place_id, image_url, caption, sort_order)
VALUES
('c1111111-1111-4111-c111-111111111111', 'b1111111-1111-4111-b111-111111111111', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80', 'Nilgiri Tahr grazing on green slopes', 1),
('c2222222-2222-4222-c222-222222222222', 'b1111111-1111-4111-b111-111111111111', 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=800&q=80', 'Mist rising over Anamudi Peak', 2),
('c3333333-3333-4333-c333-333333333333', 'b2222222-2222-4222-b222-222222222222', 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=800&q=80', 'Morning mist at Top Station lookout', 1),
('c4444444-4444-4444-c444-444444444444', 'b3333333-3333-4333-b333-333333333333', 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=800&q=80', 'Crystal clear waters of Pangong Tso', 1),
('c5555555-5555-4555-c555-555555555555', 'b4444444-4444-4444-b444-444444444444', 'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=800&q=80', 'Bactrian camel safari in Hunder dunes', 1)
ON CONFLICT (id) DO UPDATE SET image_url = EXCLUDED.image_url, caption = EXCLUDED.caption;

-- 3. Seed auth.users for Agent Profiles to satisfy foreign key constraints
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, role, aud)
VALUES
(
  'd1111111-1111-4111-d111-111111111111',
  '00000000-0000-0000-0000-000000000000',
  'priya.sharma@traveltop.com',
  '$2a$10$abcdefghijklmnopqrstuuu',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Priya Sharma","role":"agent"}',
  now(),
  now(),
  'authenticated',
  'authenticated'
),
(
  'd2222222-2222-4222-d222-222222222222',
  '00000000-0000-0000-0000-000000000000',
  'rahul.verma@traveltop.com',
  '$2a$10$abcdefghijklmnopqrstuuu',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Rahul Verma","role":"agent"}',
  now(),
  now(),
  'authenticated',
  'authenticated'
),
(
  'd3333333-3333-4333-d333-333333333333',
  '00000000-0000-0000-0000-000000000000',
  'ananya.rao@traveltop.com',
  '$2a$10$abcdefghijklmnopqrstuuu',
  now(),
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Ananya Rao","role":"agent"}',
  now(),
  now(),
  'authenticated',
  'authenticated'
)
ON CONFLICT (id) DO NOTHING;

-- Insert Sample Profiles & Agent Details
INSERT INTO profiles (id, email, full_name, role, phone, photo_url)
VALUES
('d1111111-1111-4111-d111-111111111111', 'priya.sharma@traveltop.com', 'Priya Sharma', 'agent', '+91 98765 43210', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80'),
('d2222222-2222-4222-d222-222222222222', 'rahul.verma@traveltop.com', 'Rahul Verma', 'agent', '+91 98123 45678', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80'),
('d3333333-3333-4333-d333-333333333333', 'ananya.rao@traveltop.com', 'Ananya Rao', 'agent', '+91 99887 76655', 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=400&q=80')
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, phone = EXCLUDED.phone, photo_url = EXCLUDED.photo_url;

INSERT INTO agent_details (
  id,
  bio,
  experience_years,
  languages,
  places_covered,
  price_per_day,
  verification_status,
  verified,
  suspended,
  rating_avg,
  review_count,
  safety_score,
  includes_stay,
  includes_transport,
  includes_meals
)
VALUES
(
  'd1111111-1111-4111-d111-111111111111',
  'Certified Keralite eco-tour guide with 7+ years guiding families, couples, and nature lovers around Munnar & Alleppey.',
  7,
  ARRAY['English', 'Hindi', 'Malayalam', 'Tamil'],
  ARRAY['Munnar', 'Alleppey', 'Wayanad'],
  2500,
  'approved',
  true,
  false,
  4.9,
  28,
  98,
  true,
  true,
  false
),
(
  'd2222222-2222-4222-d222-222222222222',
  'Himalayan trekking specialist & expedition lead. Native of Leh with deep knowledge of Ladakhi culture and monastery trails.',
  9,
  ARRAY['English', 'Hindi', 'Ladakhi'],
  ARRAY['Ladakh', 'Rishikesh'],
  3200,
  'approved',
  true,
  false,
  4.8,
  42,
  99,
  true,
  true,
  true
),
(
  'd3333333-3333-4333-d333-333333333333',
  'Goan heritage & coastal food explorer. Specialized in private beach tours, night markets, and Portuguese architecture walks.',
  5,
  ARRAY['English', 'Hindi', 'Konkani', 'Portuguese'],
  ARRAY['Goa'],
  2200,
  'approved',
  true,
  false,
  4.7,
  19,
  96,
  false,
  true,
  true
)
ON CONFLICT (id) DO UPDATE SET
  bio = EXCLUDED.bio,
  experience_years = EXCLUDED.experience_years,
  languages = EXCLUDED.languages,
  places_covered = EXCLUDED.places_covered,
  price_per_day = EXCLUDED.price_per_day,
  verification_status = EXCLUDED.verification_status,
  verified = EXCLUDED.verified,
  suspended = EXCLUDED.suspended,
  rating_avg = EXCLUDED.rating_avg,
  review_count = EXCLUDED.review_count;

-- 4. Insert Sample Products for Travel Gear Shop (UUID Primary Keys)
INSERT INTO products (id, name, description, price, stock, category, image_url, is_active)
VALUES
(
  'e1111111-1111-4111-e111-111111111111',
  'Waterproof Trail Backpack 45L',
  'Ergonomic, rain-protected 45L hiking pack with breathable mesh back and trekking pole mounts.',
  3499,
  15,
  'Backpacks',
  'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=600&q=80',
  true
),
(
  'e2222222-2222-4222-e222-222222222222',
  'Insulated Thermal Flask 1L',
  'Double-wall vacuum stainless steel bottle keeping beverages hot for 24h or cold for 36h.',
  1299,
  40,
  'Bottles',
  'https://images.unsplash.com/photo-1602143407151-7111542de6e8?auto=format&fit=crop&w=600&q=80',
  true
),
(
  'e3333333-3333-4333-e333-333333333333',
  'Compact Waterproof 3-Person Tent',
  'Quick-setup wind-resistant dome tent with UV protection and rainfly for mountain camping.',
  5999,
  8,
  'Camping',
  'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?auto=format&fit=crop&w=600&q=80',
  true
),
(
  'e4444444-4444-4444-e444-444444444444',
  'Ergonomic Memory Foam Neck Pillow',
  '360-degree support flight & road-trip neck pillow with washable velvet cover and earplugs.',
  699,
  50,
  'Comfort',
  'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?auto=format&fit=crop&w=600&q=80',
  true
),
(
  'e5555555-5555-4555-e555-555555555555',
  'Heavy Duty 20000mAh Power Bank',
  'Heavy duty fast-charging dual USB power bank with built-in LED torch.',
  1899,
  25,
  'Electronics',
  'https://images.unsplash.com/photo-1609592424074-b52b2f6efd6e?auto=format&fit=crop&w=600&q=80',
  true
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  price = EXCLUDED.price,
  stock = EXCLUDED.stock,
  image_url = EXCLUDED.image_url;
