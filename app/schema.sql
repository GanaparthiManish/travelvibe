-- ========================================================
-- TravelTop Supabase Database Schema DDL & RLS Policies
-- Execute this script in your Supabase Dashboard SQL Editor
-- ========================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------
-- 1. PROFILES TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('traveller', 'agent')) NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 2. AGENT_DETAILS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.agent_details (
  id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio TEXT,
  years_experience INT DEFAULT 0,
  languages TEXT[] DEFAULT '{}',
  places_covered TEXT[] DEFAULT '{}',
  price_per_day NUMERIC(10, 2) DEFAULT 0.00,
  meals_included BOOLEAN DEFAULT false,
  accommodation_included BOOLEAN DEFAULT false,
  transport_included BOOLEAN DEFAULT false,
  rating_avg NUMERIC(3, 2) DEFAULT 5.00,
  review_count INT DEFAULT 0,
  verified BOOLEAN DEFAULT false,
  verification_doc_url TEXT,
  auto_accept_bookings BOOLEAN DEFAULT false
);

-- --------------------------------------------------------
-- 3. AVAILABILITY TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.availability (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL REFERENCES public.agent_details(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  is_available BOOLEAN DEFAULT true,
  UNIQUE(agent_id, date)
);

-- --------------------------------------------------------
-- 4. BOOKINGS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  traveller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  destination TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  total_price NUMERIC(10, 2) NOT NULL,
  status TEXT CHECK (status IN ('pending', 'confirmed', 'ongoing', 'completed', 'cancelled')) DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 5. MESSAGES TABLE (Real-Time Chat)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 6. REVIEWS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  traveller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  overall_rating INT CHECK (overall_rating BETWEEN 1 AND 5) NOT NULL,
  safety_rating INT CHECK (safety_rating BETWEEN 1 AND 5) DEFAULT 5,
  punctuality_rating INT CHECK (punctuality_rating BETWEEN 1 AND 5) DEFAULT 5,
  value_rating INT CHECK (value_rating BETWEEN 1 AND 5) DEFAULT 5,
  communication_rating INT CHECK (communication_rating BETWEEN 1 AND 5) DEFAULT 5,
  review_text TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 7. PRODUCTS TABLE (Travel Gear Shop)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10, 2) NOT NULL,
  image_url TEXT,
  rating NUMERIC(3, 2) DEFAULT 4.8,
  stock INT DEFAULT 100
);

-- --------------------------------------------------------
-- 8. ORDERS TABLE (Shop Checkout)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  traveller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  items JSONB NOT NULL,
  total_amount NUMERIC(10, 2) NOT NULL,
  delivery_address TEXT NOT NULL,
  status TEXT CHECK (status IN ('placed', 'packed', 'shipped', 'out_for_delivery', 'delivered')) DEFAULT 'placed',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 9. WISHLISTS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wishlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  traveller_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(traveller_id, agent_id)
);

-- --------------------------------------------------------
-- 10. NOTIFICATIONS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  related_id UUID,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 11. PAYOUTS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  agent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount NUMERIC(10, 2) NOT NULL,
  status TEXT CHECK (status IN ('processing', 'paid')) DEFAULT 'processing',
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  paid_at TIMESTAMP WITH TIME ZONE
);

-- --------------------------------------------------------
-- 12. LOCATION_PINGS TABLE (Dead-Zone Safety Snapshots)
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.location_pings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  latitude NUMERIC NOT NULL,
  longitude NUMERIC NOT NULL,
  captured_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- --------------------------------------------------------
-- 13. EMERGENCY_SMS_LOGS TABLE
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.emergency_sms_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  recipient_number TEXT NOT NULL,
  message_content TEXT NOT NULL,
  status TEXT CHECK (status IN ('sent', 'failed')) DEFAULT 'sent',
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ALTER BOOKINGS & PROFILES
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS trip_plan TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS meeting_point TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS meeting_point_lat NUMERIC;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS meeting_point_lng NUMERIC;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS safety_opt_out BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS emergency_contact TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS delivery_address JSONB;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'en';
ALTER TABLE public.availability ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;

-- CHAT TRANSLATION & VOICE MESSAGES
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS original_language TEXT DEFAULT 'en';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS translated_text JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS audio_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS audio_duration_seconds INT DEFAULT 0;

-- DESTINATION COORDINATES
ALTER TABLE public.destinations ADD COLUMN IF NOT EXISTS latitude NUMERIC;
ALTER TABLE public.destinations ADD COLUMN IF NOT EXISTS longitude NUMERIC;

-- ========================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ========================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.location_pings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_sms_logs ENABLE ROW LEVEL SECURITY;

-- --------------------------------------------------------
-- RLS POLICIES
-- --------------------------------------------------------
CREATE POLICY "Public profiles viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Agent details viewable by everyone" ON public.agent_details FOR SELECT USING (true);
CREATE POLICY "Agents update own details" ON public.agent_details FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Agents insert own details" ON public.agent_details FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Availability viewable by everyone" ON public.availability FOR SELECT USING (true);
CREATE POLICY "Agents manage availability" ON public.availability FOR ALL USING (auth.uid() = agent_id);

CREATE POLICY "Bookings viewable by participants" ON public.bookings FOR SELECT USING (auth.uid() = traveller_id OR auth.uid() = agent_id);
CREATE POLICY "Travellers create bookings" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = traveller_id);
CREATE POLICY "Participants update booking status" ON public.bookings FOR UPDATE USING (auth.uid() = traveller_id OR auth.uid() = agent_id);

CREATE POLICY "Messages viewable by booking participants" ON public.messages FOR SELECT USING (EXISTS (
  SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
));
CREATE POLICY "Booking participants send messages" ON public.messages FOR INSERT WITH CHECK (EXISTS (
  SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
));

CREATE POLICY "Location pings viewable by booking participants" ON public.location_pings FOR SELECT USING (EXISTS (
  SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
));
CREATE POLICY "Booking participants insert location pings" ON public.location_pings FOR INSERT WITH CHECK (auth.uid() = user_id AND EXISTS (
  SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
));

CREATE POLICY "Emergency logs viewable by booking participants" ON public.emergency_sms_logs FOR SELECT USING (EXISTS (
  SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
));

CREATE POLICY "Reviews viewable by everyone" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "Travellers submit review" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = traveller_id);

CREATE POLICY "Products viewable by everyone" ON public.products FOR SELECT USING (true);

CREATE POLICY "Orders viewable by owner" ON public.orders FOR SELECT USING (auth.uid() = traveller_id);
CREATE POLICY "Travellers place orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = traveller_id);

CREATE POLICY "Wishlists viewable by owner" ON public.wishlists FOR SELECT USING (auth.uid() = traveller_id);
CREATE POLICY "Travellers manage wishlist" ON public.wishlists FOR ALL USING (auth.uid() = traveller_id);

CREATE POLICY "Notifications viewable by owner" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Notifications updated by owner" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Payouts viewable by agent" ON public.payouts FOR SELECT USING (auth.uid() = agent_id);
CREATE POLICY "Agents request payout" ON public.payouts FOR INSERT WITH CHECK (auth.uid() = agent_id);

-- ========================================================
-- REALTIME SUBSCRIPTIONS REPLICA IDENTITY
-- ========================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.availability;
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.location_pings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.emergency_sms_logs;

-- ========================================================
-- SEED SAMPLE PRODUCTS
-- ========================================================
INSERT INTO public.products (name, description, price, image_url, rating, stock)
VALUES
  ('High Peak Waterproof Backpack (45L)', 'Ergonomic 45L trekking backpack with rain cover.', 4500.00, 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400', 4.9, 50),
  ('Stainless Steel Thermal Flask 1L', 'Keeps liquids hot/cold for up to 24 hours.', 1200.00, 'https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=400', 4.8, 100),
  ('Ultralight Compact Sleeping Bag', 'Suitable for temperatures down to 5°C.', 3800.00, 'https://images.unsplash.com/photo-1510312305653-8ed496efae75?w=400', 4.7, 30)
ON CONFLICT DO NOTHING;

