-- ==============================================================================
-- TRAVELVIBE 5-FEATURE SCHEMA MIGRATION
-- ==============================================================================
-- 1. Guide Specialization Tags
-- 2. Local Insider Content (Guide Stories)
-- 3. Repeat Traveller Loyalty & Referral
-- 4. Group Booking Support
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. GUIDE SPECIALIZATION TAGS & APP SETTINGS
-- ------------------------------------------------------------------------------
ALTER TABLE public.agent_details 
  ADD COLUMN IF NOT EXISTS specialization_tags text[] DEFAULT '{}';

CREATE TABLE IF NOT EXISTS public.app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_settings_select_all" ON public.app_settings;
CREATE POLICY "app_settings_select_all" ON public.app_settings FOR SELECT USING (true);

DROP POLICY IF EXISTS "app_settings_admin_all" ON public.app_settings;
CREATE POLICY "app_settings_admin_all" ON public.app_settings FOR ALL 
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Seed initial master tags and discount configs if not exists
INSERT INTO public.app_settings (key, value)
VALUES 
  ('specialization_tags_master', '["Wildlife Expert", "Photography Tours", "Family-Friendly", "Solo Traveller Safe", "Adventure/Trekking", "Cultural & Heritage", "Budget-Friendly", "Culinary & Food Walks", "Eco & Sustainable", "Bird Watching", "Spiritual & Temple Tours"]'::jsonb),
  ('loyalty_discounts', '{"referral_discount_percent": 10, "repeat_booking_discount_percent": 5}'::jsonb)
ON CONFLICT (key) DO NOTHING;


-- ------------------------------------------------------------------------------
-- 2. LOCAL INSIDER CONTENT (GUIDE STORIES)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.guide_stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_url text NOT NULL,
  media_type text NOT NULL CHECK (media_type IN ('image', 'video')),
  caption text,
  display_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.guide_stories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "guide_stories_select_all" ON public.guide_stories;
CREATE POLICY "guide_stories_select_all" ON public.guide_stories FOR SELECT USING (true);

DROP POLICY IF EXISTS "guide_stories_agent_manage" ON public.guide_stories;
CREATE POLICY "guide_stories_agent_manage" ON public.guide_stories FOR ALL 
  USING (auth.uid() = agent_id OR public.is_admin()) 
  WITH CHECK (auth.uid() = agent_id OR public.is_admin());


-- ------------------------------------------------------------------------------
-- 3. REPEAT TRAVELLER LOYALTY & REFERRAL
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS referral_code text UNIQUE,
  ADD COLUMN IF NOT EXISTS referred_by uuid REFERENCES public.profiles(id);

CREATE TABLE IF NOT EXISTS public.loyalty_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  traveller_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  reward_type text NOT NULL CHECK (reward_type IN ('repeat_booking', 'referral')),
  description text,
  discount_percent numeric DEFAULT 10,
  is_used boolean DEFAULT false,
  related_booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.loyalty_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "loyalty_rewards_select_own" ON public.loyalty_rewards;
CREATE POLICY "loyalty_rewards_select_own" ON public.loyalty_rewards FOR SELECT 
  USING (auth.uid() = traveller_id OR public.is_admin());

DROP POLICY IF EXISTS "loyalty_rewards_update_own" ON public.loyalty_rewards;
CREATE POLICY "loyalty_rewards_update_own" ON public.loyalty_rewards FOR UPDATE 
  USING (auth.uid() = traveller_id OR public.is_admin());

DROP POLICY IF EXISTS "loyalty_rewards_insert_all" ON public.loyalty_rewards;
CREATE POLICY "loyalty_rewards_insert_all" ON public.loyalty_rewards FOR INSERT 
  WITH CHECK (auth.uid() = traveller_id OR public.is_admin());


-- ------------------------------------------------------------------------------
-- 4. GROUP BOOKING SUPPORT & AGENT ADDONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.bookings 
  ADD COLUMN IF NOT EXISTS group_size int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS group_members jsonb DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS public.agent_addons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  price numeric NOT NULL,
  per_person boolean DEFAULT false,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.agent_addons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_addons_select_all" ON public.agent_addons;
CREATE POLICY "agent_addons_select_all" ON public.agent_addons FOR SELECT USING (true);

DROP POLICY IF EXISTS "agent_addons_agent_manage" ON public.agent_addons;
CREATE POLICY "agent_addons_agent_manage" ON public.agent_addons FOR ALL 
  USING (auth.uid() = agent_id OR public.is_admin()) 
  WITH CHECK (auth.uid() = agent_id OR public.is_admin());


-- ------------------------------------------------------------------------------
-- 5. AUTO-REFERRAL CODE GENERATION TRIGGER
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_user_referral_code()
RETURNS trigger AS $$
DECLARE
  base_code text;
  final_code text;
  counter int := 0;
BEGIN
  IF NEW.referral_code IS NULL OR NEW.referral_code = '' THEN
    base_code := UPPER(REGEXP_REPLACE(COALESCE(NEW.full_name, 'USER'), '[^a-zA-Z]', '', 'g'));
    IF length(base_code) < 3 THEN
      base_code := 'TVIBE';
    ELSE
      base_code := SUBSTRING(base_code, 1, 4);
    END IF;

    LOOP
      final_code := base_code || floor(random() * (9999 - 1000 + 1) + 1000)::text;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = final_code);
      counter := counter + 1;
      IF counter > 20 THEN
        final_code := 'TV' || floor(random() * 899999 + 100000)::text;
        EXIT;
      END IF;
    END LOOP;

    NEW.referral_code := final_code;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_generate_referral_code ON public.profiles;
CREATE TRIGGER tr_generate_referral_code
  BEFORE INSERT OR UPDATE OF full_name ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_user_referral_code();

-- Populate referral code for existing profiles that don't have one
DO $$
DECLARE
  r RECORD;
  base_code text;
  final_code text;
BEGIN
  FOR r IN SELECT id, full_name FROM public.profiles WHERE referral_code IS NULL LOOP
    base_code := UPPER(REGEXP_REPLACE(COALESCE(r.full_name, 'USER'), '[^a-zA-Z]', '', 'g'));
    IF length(base_code) < 3 THEN base_code := 'TVIBE'; ELSE base_code := SUBSTRING(base_code, 1, 4); END IF;
    final_code := base_code || floor(random() * (9999 - 1000 + 1) + 1000)::text;
    UPDATE public.profiles SET referral_code = final_code WHERE id = r.id;
  END LOOP;
END $$;

-- ------------------------------------------------------------------------------
-- 6. STORAGE BUCKET & REALTIME
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('guide-stories', 'guide-stories', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "guide_stories_bucket_public" ON storage.objects;
CREATE POLICY "guide_stories_bucket_public" ON storage.objects
  FOR SELECT USING (bucket_id = 'guide-stories');

DROP POLICY IF EXISTS "guide_stories_bucket_agent_upload" ON storage.objects;
CREATE POLICY "guide_stories_bucket_agent_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'guide-stories' AND (auth.role() = 'authenticated'));

DROP POLICY IF EXISTS "guide_stories_bucket_agent_manage" ON storage.objects;
CREATE POLICY "guide_stories_bucket_agent_manage" ON storage.objects
  FOR ALL USING (bucket_id = 'guide-stories' AND (auth.role() = 'authenticated'));

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.guide_stories;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.loyalty_rewards;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

