-- =====================================================================
-- TravelVibe: Fix Announcements, Notifications, & Wishlists RLS
-- Run this in Supabase SQL Editor (Dashboard -> SQL Editor -> New Query -> Run)
-- =====================================================================

-- 1. FIX ANNOUNCEMENTS RLS
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "announcements_select_all" ON public.announcements;
DROP POLICY IF EXISTS "announcements_admin_write" ON public.announcements;
DROP POLICY IF EXISTS "Admin: all announcements" ON public.announcements;
DROP POLICY IF EXISTS "Public: read announcements" ON public.announcements;
DROP POLICY IF EXISTS "announcements_all" ON public.announcements;

CREATE POLICY "announcements_all" ON public.announcements
  FOR ALL USING (true) WITH CHECK (true);

-- 2. FIX NOTIFICATIONS RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_all" ON public.notifications;
DROP POLICY IF EXISTS "notifications_admin_write" ON public.notifications;
DROP POLICY IF EXISTS "Admin: all notifications" ON public.notifications;
DROP POLICY IF EXISTS "User: own notifications" ON public.notifications;
DROP POLICY IF EXISTS "notifications_all" ON public.notifications;

CREATE POLICY "notifications_all" ON public.notifications
  FOR ALL USING (true) WITH CHECK (true);

-- 3. FIX WISHLISTS RLS
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wishlists_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_select_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_insert_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_delete_own" ON public.wishlists;
DROP POLICY IF EXISTS "Wishlists viewable by owner" ON public.wishlists;
DROP POLICY IF EXISTS "Travellers manage wishlist" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_all" ON public.wishlists;

CREATE POLICY "wishlists_all" ON public.wishlists
  FOR ALL USING (true) WITH CHECK (true);
