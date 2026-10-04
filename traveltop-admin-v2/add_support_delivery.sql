-- Run in Supabase SQL Editor

-- 1. Add delivery_address column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS delivery_address jsonb;

-- 2. Create support_tickets table if not exists
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  subject text NOT NULL,
  category text NOT NULL DEFAULT 'Other',
  message text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','urgent','in_progress','resolved','closed')),
  admin_reply text,
  admin_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tickets_select_own" ON public.support_tickets;
DROP POLICY IF EXISTS "tickets_insert_own" ON public.support_tickets;
DROP POLICY IF EXISTS "tickets_update_admin" ON public.support_tickets;

CREATE POLICY "tickets_select_own" ON public.support_tickets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "tickets_insert_own" ON public.support_tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can update (reply/change status) — allow all for now
CREATE POLICY "tickets_update_admin" ON public.support_tickets
  FOR UPDATE USING (true) WITH CHECK (true);

-- Verify
SELECT COUNT(*) FROM public.support_tickets;
SELECT column_name FROM information_schema.columns WHERE table_name='profiles' AND column_name='delivery_address';
