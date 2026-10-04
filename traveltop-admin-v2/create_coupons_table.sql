-- Run this in Supabase SQL Editor to create public.coupons table

CREATE TABLE IF NOT EXISTS public.coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  discount_type text NOT NULL DEFAULT 'percent' CHECK (discount_type IN ('percent', 'fixed')),
  discount_value numeric NOT NULL,
  min_spend numeric DEFAULT 0,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupons_select_all" ON public.coupons;
DROP POLICY IF EXISTS "coupons_insert_admin" ON public.coupons;
DROP POLICY IF EXISTS "coupons_update_admin" ON public.coupons;
DROP POLICY IF EXISTS "coupons_delete_admin" ON public.coupons;

CREATE POLICY "coupons_select_all" ON public.coupons FOR SELECT USING (true);
CREATE POLICY "coupons_insert_admin" ON public.coupons FOR INSERT WITH CHECK (true);
CREATE POLICY "coupons_update_admin" ON public.coupons FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "coupons_delete_admin" ON public.coupons FOR DELETE USING (true);

INSERT INTO public.coupons (code, discount_type, discount_value, min_spend, description, is_active)
VALUES
  ('GUIDE25', 'percent', 25, 0, '25% OFF on first local guide booking', true),
  ('WELCOME50', 'fixed', 500, 1500, 'Flat ₹500 OFF on bookings over ₹1500', true),
  ('FIRST20', 'percent', 20, 500, '20% OFF for new users', true),
  ('GEAR10', 'percent', 10, 0, '10% OFF on outdoor gear shop', true)
ON CONFLICT (code) DO NOTHING;

SELECT * FROM public.coupons;
