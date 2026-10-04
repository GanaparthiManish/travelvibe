-- ====================================================================
-- FIX RLS POLICIES FOR ORDERS AND BOOKINGS TO ALLOW ALL INSERTS
-- ====================================================================

-- 1. ORDERS TABLE RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select_strict" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_strict" ON public.orders;
DROP POLICY IF EXISTS "orders_update_strict" ON public.orders;
DROP POLICY IF EXISTS "orders_select_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_update_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_select_own" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_own" ON public.orders;

CREATE POLICY "orders_select_all" ON public.orders
  FOR SELECT USING (true);

CREATE POLICY "orders_insert_all" ON public.orders
  FOR INSERT WITH CHECK (true);

CREATE POLICY "orders_update_all" ON public.orders
  FOR UPDATE USING (true);

-- 2. BOOKINGS TABLE RLS
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookings_select_strict" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_strict" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_strict" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;

CREATE POLICY "bookings_select_all" ON public.bookings
  FOR SELECT USING (true);

CREATE POLICY "bookings_insert_all" ON public.bookings
  FOR INSERT WITH CHECK (true);

CREATE POLICY "bookings_update_all" ON public.bookings
  FOR UPDATE USING (true);

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
