-- ==============================================================================
-- TRAVELTOP / TRAVELVIBE DATABASE FIX: WISHLISTS & SUPPORT TICKETS RLS (SAFE)
-- ==============================================================================
-- Run this script in Supabase Dashboard -> SQL Editor
-- This version skips publication changes since the tables are already in realtime.
-- ==============================================================================

-- 1. STRICT USER ISOLATION ON WISHLISTS (ZERO CROSS-USER LEAKAGE)
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wishlists_all" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_select_all" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_user_isolation" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_select_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_insert_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_delete_own" ON public.wishlists;

CREATE POLICY "wishlists_select_own" ON public.wishlists
  FOR SELECT USING (auth.uid() = traveller_id);

CREATE POLICY "wishlists_insert_own" ON public.wishlists
  FOR INSERT WITH CHECK (auth.uid() = traveller_id);

CREATE POLICY "wishlists_delete_own" ON public.wishlists
  FOR DELETE USING (auth.uid() = traveller_id);


-- 2. ALLOW BOTH TRAVELLERS AND AGENTS TO SUBMIT TICKETS
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "support_tickets_insert_strict" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_insert_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_insert_own" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_select_strict" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_select_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_own" ON public.support_tickets;
DROP POLICY IF EXISTS "tickets_select_own" ON public.support_tickets;
DROP POLICY IF EXISTS "tickets_insert_own" ON public.support_tickets;
DROP POLICY IF EXISTS "tickets_update_admin" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_insert_any_user" ON public.support_tickets;

CREATE POLICY "support_tickets_select_own" ON public.support_tickets
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "support_tickets_insert_any_user" ON public.support_tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "support_tickets_update_admin" ON public.support_tickets
  FOR UPDATE USING (public.is_admin());
