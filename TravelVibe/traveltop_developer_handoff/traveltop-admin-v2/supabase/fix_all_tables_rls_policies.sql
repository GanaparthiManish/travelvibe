-- ====================================================================
-- DEFINITIVE RLS POLICY FIX FOR ALL TABLES (TRAVELVIBE)
-- ====================================================================
-- Run this script in your Supabase SQL Editor to eliminate code: 42501 (RLS violation) errors across all tables.

-- 1. ORDERS TABLE
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "orders_all_access" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_select_policy" ON public.orders;

CREATE POLICY "orders_insert_policy" ON public.orders
  FOR INSERT WITH CHECK (true);

CREATE POLICY "orders_select_policy" ON public.orders
  FOR SELECT USING (true);

CREATE POLICY "orders_update_policy" ON public.orders
  FOR UPDATE USING (true);

-- 2. SUPPORT TICKETS TABLE
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "support_tickets_insert_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_select_policy" ON public.support_tickets;

CREATE POLICY "support_tickets_insert_policy" ON public.support_tickets
  FOR INSERT WITH CHECK (true);

CREATE POLICY "support_tickets_select_policy" ON public.support_tickets
  FOR SELECT USING (true);

-- 3. BOOKINGS TABLE
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;

CREATE POLICY "bookings_insert_policy" ON public.bookings
  FOR INSERT WITH CHECK (true);

CREATE POLICY "bookings_select_policy" ON public.bookings
  FOR SELECT USING (true);

CREATE POLICY "bookings_update_policy" ON public.bookings
  FOR UPDATE USING (true);

-- 4. NOTIFICATIONS TABLE
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notifications_insert_policy" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_policy" ON public.notifications;

CREATE POLICY "notifications_insert_policy" ON public.notifications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "notifications_select_policy" ON public.notifications
  FOR SELECT USING (true);

-- 5. MESSAGES TABLE
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;

CREATE POLICY "messages_insert_policy" ON public.messages
  FOR INSERT WITH CHECK (true);

CREATE POLICY "messages_select_policy" ON public.messages
  FOR SELECT USING (true);

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
