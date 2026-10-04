-- ====================================================================
-- FIX ORDERS TABLE RLS POLICIES FOR TRAVELLERS AND ADMINS
-- ====================================================================
-- Run this in your Supabase SQL Editor:

DROP POLICY IF EXISTS "Admin: all orders" ON public.orders;
DROP POLICY IF EXISTS "Traveller: own orders" ON public.orders;
DROP POLICY IF EXISTS "orders_select_own" ON public.orders;
DROP POLICY IF EXISTS "orders_insert_own" ON public.orders;
DROP POLICY IF EXISTS "orders_update_admin" ON public.orders;

-- 1. Allow travellers to view their own orders and admins to view all orders
CREATE POLICY "orders_select_own" ON public.orders
  FOR SELECT USING (auth.uid() = traveller_id OR public.is_admin());

-- 2. Allow travellers to place orders for themselves, and admins to create orders
CREATE POLICY "orders_insert_own" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = traveller_id OR public.is_admin());

-- 3. Allow admins to update order status (placed -> packed -> shipped -> delivered)
CREATE POLICY "orders_update_admin" ON public.orders
  FOR UPDATE USING (public.is_admin());
