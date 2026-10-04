-- ====================================================================
-- CREATE AGENT ADDONS TABLE & RLS POLICIES
-- ====================================================================
-- Run this in your Supabase SQL Editor:

CREATE TABLE IF NOT EXISTS public.agent_addons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL, -- 'accommodation', 'food', 'transport', 'other'
  name text NOT NULL,
  price_per_day numeric NOT NULL,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.agent_addons ENABLE ROW LEVEL SECURITY;

-- 1. Allow everyone to view active agent add-ons
DROP POLICY IF EXISTS "agent_addons_select" ON public.agent_addons;
CREATE POLICY "agent_addons_select" ON public.agent_addons
  FOR SELECT USING (true);

-- 2. Allow agents to manage their own add-ons and admins full access
DROP POLICY IF EXISTS "agent_addons_all_own" ON public.agent_addons;
CREATE POLICY "agent_addons_all_own" ON public.agent_addons
  FOR ALL USING (auth.uid() = agent_id OR public.is_admin());

-- Notify PostgREST schema cache
NOTIFY pgrst, 'reload schema';
