-- =====================================================
-- TRAVELVIBE — FULL SUPABASE REBUILD SCRIPT
-- =====================================================

-- =====================================================
-- 1. CORE TABLES (using IF NOT EXISTS to be safe)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'traveller',
  full_name text,
  email text,
  phone text,
  photo_url text,
  emergency_contact text,
  suspended boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.agent_details (
  id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  bio text,
  years_experience int,
  languages text[],
  places_covered text[],
  price_per_day numeric,
  meals_included boolean DEFAULT false,
  accommodation_included boolean DEFAULT false,
  transport_included boolean DEFAULT false,
  rating_avg numeric DEFAULT 0,
  review_count int DEFAULT 0,
  verified boolean DEFAULT false,
  verification_status text DEFAULT 'pending',
  rejection_reason text,
  verification_doc_url text,
  suspended boolean DEFAULT false,
  auto_accept_bookings boolean DEFAULT false,
  payout_details jsonb
);

CREATE TABLE IF NOT EXISTS public.destinations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  country text NOT NULL,
  cover_image_url text,
  description text,
  category text,
  is_featured boolean DEFAULT false,
  is_trending boolean DEFAULT false,
  best_months text[],
  risky_months text[],
  best_season text,
  travel_tips text,
  ideal_trip_duration text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.places (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id uuid REFERENCES public.destinations(id) ON DELETE CASCADE,
  name text NOT NULL,
  category text,
  description text,
  ideal_duration text,
  best_time_of_day text,
  display_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.place_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id uuid REFERENCES public.places(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.availability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  date date NOT NULL,
  is_available boolean DEFAULT true,
  UNIQUE(agent_id, date)
);

CREATE TABLE IF NOT EXISTS public.bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  traveller_id uuid REFERENCES public.profiles(id),
  agent_id uuid REFERENCES public.profiles(id),
  destination text,
  start_date date,
  end_date date,
  total_price numeric,
  status text DEFAULT 'pending',
  trip_notes text,
  admin_note text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES public.profiles(id),
  content text,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  traveller_id uuid REFERENCES public.profiles(id),
  agent_id uuid REFERENCES public.profiles(id),
  overall_rating int,
  safety_rating int,
  punctuality_rating int,
  value_rating int,
  communication_rating int,
  review_text text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wishlists (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  traveller_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(traveller_id, agent_id)
);

CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric,
  image_url text,
  rating numeric DEFAULT 0,
  stock int DEFAULT 0,
  category text
);

CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  traveller_id uuid REFERENCES public.profiles(id),
  items jsonb,
  total_amount numeric,
  delivery_address text,
  status text DEFAULT 'placed',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id),
  amount numeric,
  status text DEFAULT 'processing',
  requested_at timestamptz DEFAULT now(),
  paid_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.user_preferences (
  id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  push_notifications boolean DEFAULT true,
  dark_theme boolean DEFAULT false,
  location_services boolean DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.admin_users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text,
  role text DEFAULT 'support_staff',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text,
  body text,
  target text,
  sent_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  type text,
  title text,
  body text,
  related_id uuid,
  is_read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id),
  type text,
  description text,
  status text DEFAULT 'open',
  internal_note text,
  created_at timestamptz DEFAULT now()
);

-- Add internal_note to support_tickets if it doesn't exist (for existing tables)
ALTER TABLE public.support_tickets ADD COLUMN IF NOT EXISTS internal_note text;

-- Add category to destinations if missing
ALTER TABLE public.destinations ADD COLUMN IF NOT EXISTS category text;

-- Add category to products if missing
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category text;

-- =====================================================
-- 2. HELPER FUNCTION: is_admin
-- =====================================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
  SELECT EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid());
$$ LANGUAGE sql SECURITY DEFINER;

-- =====================================================
-- 3. AUTO-CREATE PROFILE ON SIGNUP
-- =====================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, email)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'New User'),
    COALESCE(new.raw_user_meta_data->>'role', 'traveller'),
    new.email
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_preferences (id) VALUES (new.id)
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- =====================================================
-- 4. AUTO-RECALCULATE AGENT RATING ON REVIEW CHANGE
-- =====================================================
CREATE OR REPLACE FUNCTION public.recalculate_agent_rating()
RETURNS TRIGGER AS $$
DECLARE
  target_agent_id uuid;
BEGIN
  target_agent_id := COALESCE(NEW.agent_id, OLD.agent_id);
  UPDATE public.agent_details
  SET
    rating_avg = COALESCE((SELECT AVG(overall_rating) FROM public.reviews WHERE agent_id = target_agent_id), 0),
    review_count = (SELECT COUNT(*) FROM public.reviews WHERE agent_id = target_agent_id)
  WHERE id = target_agent_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_review_change ON public.reviews;
CREATE TRIGGER on_review_change
  AFTER INSERT OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE PROCEDURE public.recalculate_agent_rating();

-- =====================================================
-- 5. BOOKING STATUS NOTIFICATION TRIGGER
-- =====================================================
CREATE OR REPLACE FUNCTION public.notify_booking_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'confirmed' OR NEW.status = 'cancelled' THEN
      INSERT INTO public.notifications (user_id, type, title, body, related_id)
      VALUES (NEW.traveller_id, 'booking_status', 'Booking Update',
        'Your booking status changed to ' || NEW.status, NEW.id);
    END IF;
    IF NEW.status = 'pending' THEN
      INSERT INTO public.notifications (user_id, type, title, body, related_id)
      VALUES (NEW.agent_id, 'new_request', 'New Booking Request',
        'You have a new booking request', NEW.id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_booking_status_change ON public.bookings;
CREATE TRIGGER on_booking_status_change
  AFTER INSERT OR UPDATE ON public.bookings
  FOR EACH ROW EXECUTE PROCEDURE public.notify_booking_change();

-- =====================================================
-- 6. NEW MESSAGE NOTIFICATION TRIGGER
-- =====================================================
CREATE OR REPLACE FUNCTION public.notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id uuid;
BEGIN
  SELECT CASE WHEN NEW.sender_id = b.traveller_id THEN b.agent_id ELSE b.traveller_id END
  INTO recipient_id
  FROM public.bookings b WHERE b.id = NEW.booking_id;

  INSERT INTO public.notifications (user_id, type, title, body, related_id)
  VALUES (recipient_id, 'new_message', 'New Message', 'You have a new message', NEW.booking_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_new_message ON public.messages;
CREATE TRIGGER on_new_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE PROCEDURE public.notify_new_message();

-- =====================================================
-- 7. ENABLE RLS ON ALL TABLES
-- =====================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 8. RLS POLICIES (drop and recreate)
-- =====================================================

-- PROFILES
DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_public_agent_view" ON public.profiles;
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "profiles_public_agent_view" ON public.profiles FOR SELECT USING (role = 'agent');

-- AGENT_DETAILS
DROP POLICY IF EXISTS "agent_details_select_all" ON public.agent_details;
DROP POLICY IF EXISTS "agent_details_update_own" ON public.agent_details;
DROP POLICY IF EXISTS "agent_details_insert_own" ON public.agent_details;
CREATE POLICY "agent_details_select_all" ON public.agent_details FOR SELECT USING (true);
CREATE POLICY "agent_details_update_own" ON public.agent_details FOR UPDATE USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "agent_details_insert_own" ON public.agent_details FOR INSERT WITH CHECK (auth.uid() = id);

-- DESTINATIONS / PLACES / PLACE_IMAGES
DROP POLICY IF EXISTS "destinations_select_all" ON public.destinations;
DROP POLICY IF EXISTS "destinations_admin_write" ON public.destinations;
CREATE POLICY "destinations_select_all" ON public.destinations FOR SELECT USING (true);
CREATE POLICY "destinations_admin_write" ON public.destinations FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "places_select_all" ON public.places;
DROP POLICY IF EXISTS "places_admin_write" ON public.places;
CREATE POLICY "places_select_all" ON public.places FOR SELECT USING (true);
CREATE POLICY "places_admin_write" ON public.places FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "place_images_select_all" ON public.place_images;
DROP POLICY IF EXISTS "place_images_admin_write" ON public.place_images;
CREATE POLICY "place_images_select_all" ON public.place_images FOR SELECT USING (true);
CREATE POLICY "place_images_admin_write" ON public.place_images FOR ALL USING (public.is_admin());

-- AVAILABILITY
DROP POLICY IF EXISTS "availability_select_all" ON public.availability;
DROP POLICY IF EXISTS "availability_agent_write" ON public.availability;
CREATE POLICY "availability_select_all" ON public.availability FOR SELECT USING (true);
CREATE POLICY "availability_agent_write" ON public.availability FOR ALL USING (auth.uid() = agent_id OR public.is_admin());

-- BOOKINGS
DROP POLICY IF EXISTS "bookings_select_own" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_traveller" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_participants" ON public.bookings;
CREATE POLICY "bookings_select_own" ON public.bookings FOR SELECT USING (auth.uid() = traveller_id OR auth.uid() = agent_id OR public.is_admin());
CREATE POLICY "bookings_insert_traveller" ON public.bookings FOR INSERT WITH CHECK (auth.uid() = traveller_id);
CREATE POLICY "bookings_update_participants" ON public.bookings FOR UPDATE USING (auth.uid() = traveller_id OR auth.uid() = agent_id OR public.is_admin());

-- MESSAGES
DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_update_read" ON public.messages;
CREATE POLICY "messages_select_participants" ON public.messages FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid()))
);
CREATE POLICY "messages_insert_participants" ON public.messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid()))
);
CREATE POLICY "messages_update_read" ON public.messages FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid()))
);

-- REVIEWS
DROP POLICY IF EXISTS "reviews_select_all" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert_traveller" ON public.reviews;
DROP POLICY IF EXISTS "reviews_delete_admin" ON public.reviews;
CREATE POLICY "reviews_select_all" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert_traveller" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = traveller_id);
CREATE POLICY "reviews_delete_admin" ON public.reviews FOR DELETE USING (public.is_admin());

-- WISHLISTS
DROP POLICY IF EXISTS "wishlists_own" ON public.wishlists;
CREATE POLICY "wishlists_own" ON public.wishlists FOR ALL USING (auth.uid() = traveller_id);

-- PRODUCTS
DROP POLICY IF EXISTS "products_select_all" ON public.products;
DROP POLICY IF EXISTS "products_admin_write" ON public.products;
CREATE POLICY "products_select_all" ON public.products FOR SELECT USING (true);
CREATE POLICY "products_admin_write" ON public.products FOR ALL USING (public.is_admin());

-- ORDERS
DROP POLICY IF EXISTS "orders_select_own" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_own" ON public.orders;
DROP POLICY IF EXISTS "orders_update_admin" ON public.orders;
CREATE POLICY "orders_select_own" ON public.orders FOR SELECT USING (auth.uid() = traveller_id OR public.is_admin());
CREATE POLICY "orders_insert_own" ON public.orders FOR INSERT WITH CHECK (auth.uid() = traveller_id);
CREATE POLICY "orders_update_admin" ON public.orders FOR UPDATE USING (public.is_admin());

-- PAYOUTS
DROP POLICY IF EXISTS "payouts_select_own" ON public.payouts;
DROP POLICY IF EXISTS "payouts_insert_own" ON public.payouts;
DROP POLICY IF EXISTS "payouts_update_admin" ON public.payouts;
CREATE POLICY "payouts_select_own" ON public.payouts FOR SELECT USING (auth.uid() = agent_id OR public.is_admin());
CREATE POLICY "payouts_insert_own" ON public.payouts FOR INSERT WITH CHECK (auth.uid() = agent_id);
CREATE POLICY "payouts_update_admin" ON public.payouts FOR UPDATE USING (public.is_admin());

-- USER_PREFERENCES
DROP POLICY IF EXISTS "user_preferences_own" ON public.user_preferences;
CREATE POLICY "user_preferences_own" ON public.user_preferences FOR ALL USING (auth.uid() = id);

-- ADMIN_USERS
DROP POLICY IF EXISTS "admin_users_select" ON public.admin_users;
DROP POLICY IF EXISTS "admin_users_write" ON public.admin_users;
CREATE POLICY "admin_users_select" ON public.admin_users FOR SELECT USING (public.is_admin());
CREATE POLICY "admin_users_write" ON public.admin_users FOR ALL USING (
  EXISTS (SELECT 1 FROM public.admin_users WHERE id = auth.uid() AND role = 'super_admin')
);

-- ANNOUNCEMENTS
DROP POLICY IF EXISTS "announcements_select_all" ON public.announcements;
DROP POLICY IF EXISTS "announcements_admin_write" ON public.announcements;
CREATE POLICY "announcements_select_all" ON public.announcements FOR SELECT USING (true);
CREATE POLICY "announcements_admin_write" ON public.announcements FOR ALL USING (public.is_admin());

-- NOTIFICATIONS
DROP POLICY IF EXISTS "notifications_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_admin_insert" ON public.notifications;
CREATE POLICY "notifications_own" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "notifications_update_own" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "notifications_admin_insert" ON public.notifications FOR INSERT WITH CHECK (true);

-- SUPPORT TICKETS
DROP POLICY IF EXISTS "support_tickets_own" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_insert_own" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_update_admin" ON public.support_tickets;
CREATE POLICY "support_tickets_own" ON public.support_tickets FOR SELECT USING (auth.uid() = user_id OR public.is_admin());
CREATE POLICY "support_tickets_insert_own" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "support_tickets_update_admin" ON public.support_tickets FOR UPDATE USING (public.is_admin());

-- =====================================================
-- 9. STORAGE BUCKETS
-- =====================================================
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('destination-images', 'destination-images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('place-images', 'place-images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('verification-docs', 'verification-docs', false) ON CONFLICT DO NOTHING;

DROP POLICY IF EXISTS "public_read_avatars" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_avatars" ON storage.objects;
DROP POLICY IF EXISTS "public_read_destination_images" ON storage.objects;
DROP POLICY IF EXISTS "admin_upload_destination_images" ON storage.objects;
DROP POLICY IF EXISTS "public_read_place_images" ON storage.objects;
DROP POLICY IF EXISTS "admin_upload_place_images" ON storage.objects;
DROP POLICY IF EXISTS "public_read_product_images" ON storage.objects;
DROP POLICY IF EXISTS "admin_upload_product_images" ON storage.objects;
DROP POLICY IF EXISTS "owner_admin_read_verification_docs" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_verification_docs" ON storage.objects;

CREATE POLICY "public_read_avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "auth_upload_avatars" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "public_read_destination_images" ON storage.objects FOR SELECT USING (bucket_id = 'destination-images');
CREATE POLICY "admin_upload_destination_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'destination-images' AND public.is_admin());
CREATE POLICY "public_read_place_images" ON storage.objects FOR SELECT USING (bucket_id = 'place-images');
CREATE POLICY "admin_upload_place_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'place-images' AND public.is_admin());
CREATE POLICY "public_read_product_images" ON storage.objects FOR SELECT USING (bucket_id = 'product-images');
CREATE POLICY "admin_upload_product_images" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'product-images' AND public.is_admin());
CREATE POLICY "owner_admin_read_verification_docs" ON storage.objects FOR SELECT USING (
  bucket_id = 'verification-docs' AND (auth.uid()::text = (storage.foldername(name))[1] OR public.is_admin())
);
CREATE POLICY "auth_upload_verification_docs" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'verification-docs' AND auth.role() = 'authenticated'
);

-- =====================================================
-- 10. ENABLE REALTIME
-- =====================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.availability;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE public.agent_details;
ALTER PUBLICATION supabase_realtime ADD TABLE public.payouts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.destinations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.places;
ALTER PUBLICATION supabase_realtime ADD TABLE public.support_tickets;

-- =====================================================
-- DONE
-- =====================================================
