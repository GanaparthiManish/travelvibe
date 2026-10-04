-- ====================================================================
-- STRICT SINGLE SOURCE OF TRUTH RLS POLICIES FOR TRAVELVIBE
-- ====================================================================

-- 1. BOOKINGS TABLE
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookings_select_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select_strict" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_policy" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_policy" ON public.bookings;

CREATE POLICY "bookings_select_strict" ON public.bookings
  FOR SELECT USING (auth.uid() = traveller_id OR auth.uid() = agent_id OR public.is_admin());

CREATE POLICY "bookings_insert_strict" ON public.bookings
  FOR INSERT WITH CHECK (auth.uid() = traveller_id OR public.is_admin());

CREATE POLICY "bookings_update_strict" ON public.bookings
  FOR UPDATE USING (auth.uid() = traveller_id OR auth.uid() = agent_id OR public.is_admin());

-- 2. ORDERS TABLE
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_select_strict" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_policy" ON public.orders;
DROP POLICY IF EXISTS "orders_update_policy" ON public.orders;

CREATE POLICY "orders_select_strict" ON public.orders
  FOR SELECT USING (auth.uid() = traveller_id OR public.is_admin());

CREATE POLICY "orders_insert_strict" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = traveller_id OR public.is_admin());

CREATE POLICY "orders_update_strict" ON public.orders
  FOR UPDATE USING (auth.uid() = traveller_id OR public.is_admin());

-- 3. SUPPORT TICKETS TABLE
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "support_tickets_select_policy" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_select_strict" ON public.support_tickets;
DROP POLICY IF EXISTS "support_tickets_insert_policy" ON public.support_tickets;

CREATE POLICY "support_tickets_select_strict" ON public.support_tickets
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "support_tickets_insert_strict" ON public.support_tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id OR public.is_admin());

-- 4. MESSAGES TABLE
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "messages_select_policy" ON public.messages;
DROP POLICY IF EXISTS "messages_select_strict" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_policy" ON public.messages;

CREATE POLICY "messages_select_strict" ON public.messages
  FOR SELECT USING (auth.uid() = sender_id OR public.is_admin());

CREATE POLICY "messages_insert_strict" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id OR public.is_admin());

-- 5. PRODUCTS TABLE
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "products_select_public" ON public.products;
DROP POLICY IF EXISTS "products_all_authenticated" ON public.products;

CREATE POLICY "products_select_public" ON public.products
  FOR SELECT USING (true);

CREATE POLICY "products_all_authenticated" ON public.products
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 6. AGENT GALLERY TABLE
ALTER TABLE public.agent_gallery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_gallery_select_public" ON public.agent_gallery;
DROP POLICY IF EXISTS "agent_gallery_all_authenticated" ON public.agent_gallery;

CREATE POLICY "agent_gallery_select_public" ON public.agent_gallery
  FOR SELECT USING (true);

CREATE POLICY "agent_gallery_all_authenticated" ON public.agent_gallery
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- 7. AGENT DOCUMENTS TABLE
ALTER TABLE public.agent_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_documents_select_strict" ON public.agent_documents;
DROP POLICY IF EXISTS "agent_documents_all_authenticated" ON public.agent_documents;

CREATE POLICY "agent_documents_select_strict" ON public.agent_documents
  FOR SELECT USING (auth.uid() = agent_id OR public.is_admin());

CREATE POLICY "agent_documents_all_authenticated" ON public.agent_documents
  FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
