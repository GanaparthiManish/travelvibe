-- ============================================================
-- TravelTop Admin — Supabase SQL Migration
-- Run this in the Supabase SQL Editor (project → SQL Editor)
-- ============================================================

-- ── 1. CREATE TABLES (if not already created by the apps) ──────

create table if not exists admin_users (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'support_staff' check (role in ('super_admin','support_staff')),
  created_at timestamptz default now()
);

create table if not exists destinations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  country text,
  cover_image_url text,
  description text,
  is_featured boolean default false,
  is_trending boolean default false,
  best_months text[] default '{}',
  risky_months text[] default '{}',
  best_season text,
  travel_tips text,
  ideal_trip_duration text,
  created_at timestamptz default now()
);

create table if not exists places (
  id uuid primary key default gen_random_uuid(),
  destination_id uuid references destinations(id) on delete cascade,
  name text not null,
  category text,
  description text,
  ideal_duration text,
  best_time_of_day text,
  display_order int default 0,
  created_at timestamptz default now()
);

create table if not exists place_images (
  id uuid primary key default gen_random_uuid(),
  place_id uuid references places(id) on delete cascade,
  image_url text not null,
  display_order int default 0
);

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text default 'traveller',
  full_name text,
  email text,
  phone text,
  photo_url text,
  suspended boolean default false,
  emergency_contact text,
  created_at timestamptz default now()
);

create table if not exists agent_details (
  id uuid primary key references profiles(id) on delete cascade,
  bio text,
  years_experience int default 0,
  languages text[] default '{}',
  places_covered text[] default '{}',
  price_per_day numeric default 0,
  meals_included boolean default false,
  accommodation_included boolean default false,
  transport_included boolean default false,
  rating_avg numeric default 0,
  review_count int default 0,
  verified boolean default false,
  verification_status text default 'under_review'
    check (verification_status in ('under_review','approved','rejected')),
  rejection_reason text,
  verification_doc_url text,
  suspended boolean default false,
  auto_accept_bookings boolean default false
);

create table if not exists availability (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid references profiles(id) on delete cascade,
  date date not null,
  is_available boolean default true
);

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  traveller_id uuid references profiles(id),
  agent_id uuid references agent_details(id),
  destination text,
  start_date date,
  end_date date,
  total_price numeric default 0,
  status text default 'pending'
    check (status in ('pending','confirmed','completed','cancelled')),
  trip_notes text,
  admin_note text,
  created_at timestamptz default now()
);

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete cascade,
  sender_id uuid references profiles(id),
  content text,
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete cascade,
  traveller_id uuid references profiles(id),
  agent_id uuid references agent_details(id),
  overall_rating numeric check (overall_rating between 1 and 5),
  safety_rating numeric,
  punctuality_rating numeric,
  value_rating numeric,
  communication_rating numeric,
  review_text text,
  created_at timestamptz default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric default 0,
  image_url text,
  rating numeric default 0,
  stock int default 0,
  created_at timestamptz default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  traveller_id uuid references profiles(id),
  items jsonb,
  total_amount numeric default 0,
  delivery_address text,
  status text default 'placed'
    check (status in ('placed','packed','shipped','out_for_delivery','delivered')),
  created_at timestamptz default now()
);

create table if not exists payouts (
  id uuid primary key default gen_random_uuid(),
  agent_id uuid references agent_details(id),
  amount numeric default 0,
  status text default 'requested' check (status in ('requested','paid','failed')),
  requested_at timestamptz default now(),
  paid_at timestamptz
);

create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  target text default 'all' check (target in ('all','agents','travellers')),
  sent_at timestamptz default now()
);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  type text,
  title text,
  body text,
  related_id uuid,
  is_read boolean default false,
  created_at timestamptz default now()
);

-- ── 2. ENABLE ROW LEVEL SECURITY ───────────────────────────────

alter table admin_users        enable row level security;
alter table destinations       enable row level security;
alter table places             enable row level security;
alter table place_images       enable row level security;
alter table profiles           enable row level security;
alter table agent_details      enable row level security;
alter table availability       enable row level security;
alter table bookings           enable row level security;
alter table messages           enable row level security;
alter table reviews            enable row level security;
alter table products           enable row level security;
alter table orders             enable row level security;
alter table payouts            enable row level security;
alter table announcements      enable row level security;
alter table notifications      enable row level security;

-- ── 3. HELPER FUNCTION: is_admin() ────────────────────────────
-- Returns true if the calling user has a row in admin_users.

create or replace function is_admin()
returns boolean language sql security definer as $$
  select exists (
    select 1 from admin_users where id = auth.uid()
  );
$$;

create or replace function is_super_admin()
returns boolean language sql security definer as $$
  select exists (
    select 1 from admin_users where id = auth.uid() and role = 'super_admin'
  );
$$;

-- ── 4. ADMIN FULL ACCESS POLICIES ─────────────────────────────
-- Admins can read/write everything.

-- admin_users
drop policy if exists "Admin: read admin_users" on admin_users;
create policy "Admin: read admin_users" on admin_users
  for select using (is_admin());

drop policy if exists "Admin: write admin_users" on admin_users;
create policy "Admin: write admin_users" on admin_users
  for all using (is_super_admin()) with check (is_super_admin());

-- destinations
drop policy if exists "Admin: all destinations" on destinations;
create policy "Admin: all destinations" on destinations
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Public: read destinations" on destinations;
create policy "Public: read destinations" on destinations
  for select using (true);

-- places
drop policy if exists "Admin: all places" on places;
create policy "Admin: all places" on places
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Public: read places" on places;
create policy "Public: read places" on places
  for select using (true);

-- place_images
drop policy if exists "Admin: all place_images" on place_images;
create policy "Admin: all place_images" on place_images
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Public: read place_images" on place_images;
create policy "Public: read place_images" on place_images
  for select using (true);

-- profiles
drop policy if exists "Admin: all profiles" on profiles;
create policy "Admin: all profiles" on profiles
  for all using (is_admin()) with check (is_admin());

drop policy if exists "User: read own profile" on profiles;
create policy "User: read own profile" on profiles
  for select using (auth.uid() = id);

drop policy if exists "User: update own profile" on profiles;
create policy "User: update own profile" on profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "User: insert own profile" on profiles;
create policy "User: insert own profile" on profiles
  for insert with check (auth.uid() = id);

-- agent_details
drop policy if exists "Admin: all agent_details" on agent_details;
create policy "Admin: all agent_details" on agent_details
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Agent: read own details" on agent_details;
create policy "Agent: read own details" on agent_details
  for select using (auth.uid() = id);

drop policy if exists "Agent: update own details" on agent_details;
create policy "Agent: update own details" on agent_details
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Agent: insert own details" on agent_details;
create policy "Agent: insert own details" on agent_details
  for insert with check (auth.uid() = id);

drop policy if exists "Public: read approved agents" on agent_details;
create policy "Public: read approved agents" on agent_details
  for select using (verification_status = 'approved' and suspended = false);

-- availability
drop policy if exists "Admin: all availability" on availability;
create policy "Admin: all availability" on availability
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Agent: manage own availability" on availability;
create policy "Agent: manage own availability" on availability
  for all using (auth.uid() = agent_id) with check (auth.uid() = agent_id);

drop policy if exists "Public: read availability" on availability;
create policy "Public: read availability" on availability
  for select using (true);

-- bookings
drop policy if exists "Admin: all bookings" on bookings;
create policy "Admin: all bookings" on bookings
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Traveller: own bookings" on bookings;
create policy "Traveller: own bookings" on bookings
  for all using (auth.uid() = traveller_id) with check (auth.uid() = traveller_id);

drop policy if exists "Agent: assigned bookings" on bookings;
create policy "Agent: assigned bookings" on bookings
  for select using (auth.uid() = agent_id);

drop policy if exists "Agent: update assigned bookings" on bookings;
create policy "Agent: update assigned bookings" on bookings
  for update using (auth.uid() = agent_id);

-- messages
drop policy if exists "Admin: all messages" on messages;
create policy "Admin: all messages" on messages
  for all using (is_admin()) with check (is_admin());

drop policy if exists "User: own messages" on messages;
create policy "User: own messages" on messages
  for all using (auth.uid() = sender_id) with check (auth.uid() = sender_id);

drop policy if exists "User: read booking messages" on messages;
create policy "User: read booking messages" on messages
  for select using (
    exists (
      select 1 from bookings b
      where b.id = booking_id
        and (b.traveller_id = auth.uid() or b.agent_id = auth.uid())
    )
  );

-- reviews
drop policy if exists "Admin: all reviews" on reviews;
create policy "Admin: all reviews" on reviews
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Traveller: write own review" on reviews;
create policy "Traveller: write own review" on reviews
  for all using (auth.uid() = traveller_id) with check (auth.uid() = traveller_id);

drop policy if exists "Public: read reviews" on reviews;
create policy "Public: read reviews" on reviews
  for select using (true);

-- products
drop policy if exists "Admin: all products" on products;
create policy "Admin: all products" on products
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Public: read products" on products;
create policy "Public: read products" on products
  for select using (true);

-- orders
drop policy if exists "Admin: all orders" on orders;
create policy "Admin: all orders" on orders
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Traveller: own orders" on orders;
create policy "Traveller: own orders" on orders
  for all using (auth.uid() = traveller_id) with check (auth.uid() = traveller_id);

-- payouts
drop policy if exists "Admin: all payouts" on payouts;
create policy "Admin: all payouts" on payouts
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Agent: own payouts" on payouts;
create policy "Agent: own payouts" on payouts
  for all using (auth.uid() = agent_id) with check (auth.uid() = agent_id);

-- announcements
drop policy if exists "Admin: all announcements" on announcements;
create policy "Admin: all announcements" on announcements
  for all using (is_admin()) with check (is_admin());

drop policy if exists "Public: read announcements" on announcements;
create policy "Public: read announcements" on announcements
  for select using (true);

-- notifications
drop policy if exists "Admin: all notifications" on notifications;
create policy "Admin: all notifications" on notifications
  for all using (is_admin()) with check (is_admin());

drop policy if exists "User: own notifications" on notifications;
create policy "User: own notifications" on notifications
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── 5. STORAGE BUCKETS ─────────────────────────────────────────
-- Run these separately or use the Supabase Dashboard → Storage UI.
-- Create these buckets as PUBLIC (for destination/place/product images)
-- and PRIVATE (for verification-docs):
--
--   destination-images  (public)
--   place-images        (public)
--   product-images      (public)
--   verification-docs   (private)
--
-- Then add these storage policies:

-- Allow admins to upload to all buckets
insert into storage.buckets (id, name, public) values
  ('destination-images', 'destination-images', true),
  ('place-images', 'place-images', true),
  ('product-images', 'product-images', true),
  ('verification-docs', 'verification-docs', false)
on conflict (id) do nothing;

create policy "Admin upload destination-images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'destination-images' and is_admin()
  );
create policy "Public read destination-images" on storage.objects
  for select using (bucket_id = 'destination-images');

create policy "Admin upload place-images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'place-images' and is_admin()
  );
create policy "Public read place-images" on storage.objects
  for select using (bucket_id = 'place-images');

create policy "Admin upload product-images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'product-images' and is_admin()
  );
create policy "Public read product-images" on storage.objects
  for select using (bucket_id = 'product-images');

create policy "Agent upload verification-docs" on storage.objects
  for insert to authenticated with check (bucket_id = 'verification-docs');
create policy "Admin read verification-docs" on storage.objects
  for select using (bucket_id = 'verification-docs' and is_admin());

-- ── 6. SEED: Your first super_admin ───────────────────────────
-- After signing up with your email in Supabase Auth, run:
-- (Replace the UUID with your actual auth.users id from the Supabase dashboard)
--
-- insert into admin_users (id, full_name, role) values
--   ('YOUR-UUID-HERE', 'Your Name', 'super_admin');

-- ── 7. ENABLE REALTIME ─────────────────────────────────────────
-- In Supabase Dashboard → Database → Replication, enable these tables:
--   profiles, agent_details, bookings, orders, payouts, reviews,
--   destinations, products, notifications, announcements

-- Done! ✓
