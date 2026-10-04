-- =====================================================
-- FIX PLACES & PLACE_IMAGES TABLES & RLS POLICIES
-- Run this in Supabase SQL Editor to guarantee place creation & fetching
-- =====================================================

-- 1. Ensure places table exists with all columns
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

-- Ensure missing columns exist
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS destination_id uuid REFERENCES public.destinations(id) ON DELETE CASCADE;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS ideal_duration text;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS best_time_of_day text;
ALTER TABLE public.places ADD COLUMN IF NOT EXISTS display_order int DEFAULT 0;

-- 2. Ensure place_images table exists with all columns
CREATE TABLE IF NOT EXISTS public.place_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id uuid REFERENCES public.places(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int DEFAULT 0,
  sort_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Ensure missing columns exist
ALTER TABLE public.place_images ADD COLUMN IF NOT EXISTS place_id uuid REFERENCES public.places(id) ON DELETE CASCADE;
ALTER TABLE public.place_images ADD COLUMN IF NOT EXISTS image_url text;
ALTER TABLE public.place_images ADD COLUMN IF NOT EXISTS display_order int DEFAULT 0;
ALTER TABLE public.place_images ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0;

-- 3. RLS Policies for places & place_images
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.place_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "places_select_all" ON public.places;
DROP POLICY IF EXISTS "places_all_authenticated" ON public.places;
DROP POLICY IF EXISTS "places_all_anon" ON public.places;

CREATE POLICY "places_select_all" ON public.places FOR SELECT USING (true);
CREATE POLICY "places_all_authenticated" ON public.places FOR ALL USING (true);

DROP POLICY IF EXISTS "place_images_select_all" ON public.place_images;
DROP POLICY IF EXISTS "place_images_all_authenticated" ON public.place_images;

CREATE POLICY "place_images_select_all" ON public.place_images FOR SELECT USING (true);
CREATE POLICY "place_images_all_authenticated" ON public.place_images FOR ALL USING (true);

-- 4. Enable Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.places;
ALTER PUBLICATION supabase_realtime ADD TABLE public.place_images;
