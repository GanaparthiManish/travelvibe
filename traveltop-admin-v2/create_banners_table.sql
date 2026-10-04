-- ============================================================
-- STEP 1: Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- This creates the banners table for Admin Promotional Banners
-- ============================================================

CREATE TABLE IF NOT EXISTS public.banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  image_url text,
  badge_text text DEFAULT 'SPECIAL OFFER',
  banner_type text NOT NULL CHECK (banner_type IN ('agent_discount', 'shop_item', 'destination')),
  target_id text,
  display_order int DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- Drop old policies if they exist
DROP POLICY IF EXISTS "banners_select_all" ON public.banners;
DROP POLICY IF EXISTS "banners_insert_admin" ON public.banners;
DROP POLICY IF EXISTS "banners_update_admin" ON public.banners;
DROP POLICY IF EXISTS "banners_delete_admin" ON public.banners;

-- Allow full public access (admin manages via service role in production)
CREATE POLICY "banners_select_all"   ON public.banners FOR SELECT USING (true);
CREATE POLICY "banners_insert_admin" ON public.banners FOR INSERT WITH CHECK (true);
CREATE POLICY "banners_update_admin" ON public.banners FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "banners_delete_admin" ON public.banners FOR DELETE USING (true);

-- ============================================================
-- STEP 2: Seed the 2 default promotional banners
-- ============================================================

INSERT INTO public.banners (title, subtitle, badge_text, banner_type, image_url, display_order, is_active)
VALUES
  (
    'Get 25% OFF Your First Local Guide!',
    'Book verified local experts in Khajjiar & Munnar with code GUIDE25.',
    'FLAT 25% OFF',
    'agent_discount',
    'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80',
    1,
    true
  ),
  (
    'Essential Trekking & Outdoor Gear',
    'High-performance backpacks, boots & jackets with free express delivery.',
    'GEAR STORE',
    'shop_item',
    'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=1200&q=80',
    2,
    true
  )
ON CONFLICT DO NOTHING;

-- ============================================================
-- STEP 3: Verify - should show 2 rows
-- ============================================================
SELECT id, title, banner_type, is_active, display_order FROM public.banners ORDER BY display_order;
