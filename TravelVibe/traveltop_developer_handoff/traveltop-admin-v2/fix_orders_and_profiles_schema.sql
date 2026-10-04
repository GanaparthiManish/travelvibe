-- =============================================================
-- FIX SUPABASE SCHEMAS & RLS FOR ORDERS & PROFILES
-- =============================================================

-- 1. Alter orders.id column to TEXT so string IDs like 'TV-ORD-8574034' work cleanly
ALTER TABLE public.orders ALTER COLUMN id TYPE text USING id::text;

-- 2. Ensure RLS on orders allows admin and traveller read/write access
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select_own" ON public.orders;
DROP POLICY IF EXISTS "orders_select_all_admin" ON public.orders;
CREATE POLICY "orders_select_all" ON public.orders FOR SELECT USING (true);

DROP POLICY IF EXISTS "orders_insert_all" ON public.orders;
CREATE POLICY "orders_insert_all" ON public.orders FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "orders_update_admin" ON public.orders;
CREATE POLICY "orders_update_admin" ON public.orders FOR UPDATE USING (true);

-- 3. Ensure profiles RLS permits public/admin read
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_all" ON public.profiles;
CREATE POLICY "profiles_select_all" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_insert_all" ON public.profiles;
CREATE POLICY "profiles_insert_all" ON public.profiles FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_update_all" ON public.profiles;
CREATE POLICY "profiles_update_all" ON public.profiles FOR UPDATE USING (true);

-- 4. Upsert missing traveller profiles into profiles table
INSERT INTO public.profiles (id, role, full_name, email, phone, created_at)
VALUES 
  ('ecomartx1@gmail.com', 'traveller', 'Eco MartX', 'ecomartx1@gmail.com', '+91 98765 43210', NOW()),
  ('cdc23bc0-6b3c-4017-b3c5-38b37099bd23', 'traveller', 'Ganaparthi Manish chowdary', 'ganaparthimanishchowdary@gmail.com', '+91 88978 68951', NOW())
ON CONFLICT (id) DO UPDATE SET 
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  role = EXCLUDED.role;

-- 5. Backfill existing orders from banners store into orders table
INSERT INTO public.orders (id, traveller_id, total_amount, status, delivery_address, created_at)
VALUES
  (
    'TV-ORD-8574034',
    'ecomartx1@gmail.com',
    769,
    'packed',
    '{"line1": "Flat 402, Royal Residency", "line2": "Jubilee Hills, Road No. 36", "city": "Hyderabad", "pincode": "500033", "phone": "+91 98765 43210"}'::jsonb,
    '2026-08-22T03:12:54.034353'::timestamptz
  ),
  (
    'TV-ORD-8311601',
    'cdc23bc0-6b3c-4017-b3c5-38b37099bd23',
    249,
    'packed',
    '{"line1": "Flat 402, Royal Residency", "line2": "Jubilee Hills, Road No. 36", "city": "Hyderabad", "pincode": "500033", "phone": "+91 98765 43210"}'::jsonb,
    '2026-08-22T03:08:31.601645'::timestamptz
  )
ON CONFLICT (id) DO UPDATE SET
  status = EXCLUDED.status,
  total_amount = EXCLUDED.total_amount,
  delivery_address = EXCLUDED.delivery_address;
