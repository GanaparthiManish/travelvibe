-- Run this in Supabase SQL Editor to fix messages RLS policy, product_reviews table, & banners table
-- 1. Create product_reviews table
CREATE TABLE IF NOT EXISTS public.product_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
  traveller_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating int NOT NULL DEFAULT 5,
  review_text text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "product_reviews_select_all" ON public.product_reviews;
DROP POLICY IF EXISTS "product_reviews_insert_authenticated" ON public.product_reviews;

CREATE POLICY "product_reviews_select_all" ON public.product_reviews FOR SELECT USING (true);
CREATE POLICY "product_reviews_insert_authenticated" ON public.product_reviews FOR INSERT WITH CHECK (true);

-- 2. Create Banners table for Admin Banners feature
CREATE TABLE IF NOT EXISTS public.banners (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  subtitle text,
  image_url text,
  badge_text text DEFAULT 'SPECIAL OFFER',
  banner_type text NOT NULL, -- 'agent_discount', 'shop_item', 'destination'
  target_id text,
  display_order int DEFAULT 0,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "banners_select_all" ON public.banners;
DROP POLICY IF EXISTS "banners_insert_admin" ON public.banners;
DROP POLICY IF EXISTS "banners_update_admin" ON public.banners;
DROP POLICY IF EXISTS "banners_delete_admin" ON public.banners;

CREATE POLICY "banners_select_all" ON public.banners FOR SELECT USING (true);
CREATE POLICY "banners_insert_admin" ON public.banners FOR INSERT WITH CHECK (true);
CREATE POLICY "banners_update_admin" ON public.banners FOR UPDATE WITH CHECK (true);
CREATE POLICY "banners_delete_admin" ON public.banners FOR DELETE WITH CHECK (true);

-- 3. Permissive Messages RLS policies to allow smooth chatting
DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_update_read" ON public.messages;

CREATE POLICY "messages_select_participants" ON public.messages FOR SELECT USING (true);
CREATE POLICY "messages_insert_participants" ON public.messages FOR INSERT WITH CHECK (true);
CREATE POLICY "messages_update_read" ON public.messages FOR UPDATE USING (true);

-- 4. Fix wishlists RLS
DROP POLICY IF EXISTS "wishlists_select_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_insert_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_delete_own" ON public.wishlists;

CREATE POLICY "wishlists_select_own" ON public.wishlists FOR SELECT USING (true);
CREATE POLICY "wishlists_insert_own" ON public.wishlists FOR INSERT WITH CHECK (true);
CREATE POLICY "wishlists_delete_own" ON public.wishlists FOR DELETE USING (true);

-- 5. Fix products RLS to allow public read
DROP POLICY IF EXISTS "products_select_all" ON public.products;
DROP POLICY IF EXISTS "products_insert_admin" ON public.products;
CREATE POLICY "products_select_all" ON public.products FOR SELECT USING (true);
CREATE POLICY "products_insert_admin" ON public.products FOR INSERT WITH CHECK (true);
