-- ==============================================================================
-- TRAVELVIBE SIMPLIFIED PAYMENT & SAFETY MODEL MIGRATION (FINAL)
-- ==============================================================================
-- 1. Agent Payout Methods (Bank/UPI with Fuzzy Name Matching)
-- 2. Guide Fee Only Staged Release (50% Start / 50% Completion)
-- 3. Informational Estimated Daily Expenses
-- 4. Emergency / SOS Safety Flow (sos_incidents)
-- 5. Post-Trip Expense Reconciliation Logs (trip_expense_logs)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. AGENT PAYOUT METHODS TABLE & RLS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.agent_payout_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
  method_type text NOT NULL CHECK (method_type IN ('bank', 'upi')),
  account_holder_name text NOT NULL,
  bank_account_number text,
  ifsc_code text,
  upi_id text,
  name_verified boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.agent_payout_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_payout_methods_select" ON public.agent_payout_methods;
CREATE POLICY "agent_payout_methods_select" ON public.agent_payout_methods FOR SELECT
  USING (auth.uid() = agent_id OR public.is_admin());

DROP POLICY IF EXISTS "agent_payout_methods_insert" ON public.agent_payout_methods;
CREATE POLICY "agent_payout_methods_insert" ON public.agent_payout_methods FOR INSERT
  WITH CHECK (auth.uid() = agent_id OR public.is_admin());

DROP POLICY IF EXISTS "agent_payout_methods_update" ON public.agent_payout_methods;
CREATE POLICY "agent_payout_methods_update" ON public.agent_payout_methods FOR UPDATE
  USING (auth.uid() = agent_id OR public.is_admin())
  WITH CHECK (auth.uid() = agent_id OR public.is_admin());


-- ------------------------------------------------------------------------------
-- 2. SIMPLIFIED GUIDE FEE & ESTIMATED EXPENSES BOOKINGS COLUMNS
-- ------------------------------------------------------------------------------
ALTER TABLE public.bookings 
  ADD COLUMN IF NOT EXISTS guide_fee_total numeric,
  ADD COLUMN IF NOT EXISTS estimated_daily_expenses numeric,
  ADD COLUMN IF NOT EXISTS trip_started_at timestamptz,
  ADD COLUMN IF NOT EXISTS traveller_confirmed_start boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS agent_confirmed_start boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS payout_start_released boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS payout_final_released boolean DEFAULT false;

-- Allow agents to specify their standard daily cash expense recommendation
ALTER TABLE public.agent_details
  ADD COLUMN IF NOT EXISTS estimated_daily_expenses numeric DEFAULT 1500;

-- Enhance payouts table if not exists or add booking tracking columns
CREATE TABLE IF NOT EXISTS public.payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount numeric NOT NULL,
  status text DEFAULT 'processing',
  requested_at timestamptz DEFAULT now(),
  paid_at timestamptz,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  payout_stage int,
  notes text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.payouts 
  ADD COLUMN IF NOT EXISTS booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS payout_stage int,
  ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payouts_select" ON public.payouts;
CREATE POLICY "payouts_select" ON public.payouts FOR SELECT
  USING (auth.uid() = agent_id OR public.is_admin());

DROP POLICY IF EXISTS "payouts_insert" ON public.payouts;
CREATE POLICY "payouts_insert" ON public.payouts FOR INSERT
  WITH CHECK (auth.uid() = agent_id OR public.is_admin());

DROP POLICY IF EXISTS "payouts_update_admin" ON public.payouts;
CREATE POLICY "payouts_update_admin" ON public.payouts FOR UPDATE
  USING (public.is_admin());


-- ------------------------------------------------------------------------------
-- 3. EMERGENCY / SOS SAFETY FLOW (sos_incidents)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sos_incidents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  triggered_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  triggered_by_role text CHECK (triggered_by_role IN ('traveller', 'agent')),
  last_known_lat numeric,
  last_known_lng numeric,
  status text DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'false_alarm')),
  admin_notes text,
  created_at timestamptz DEFAULT now(),
  resolved_at timestamptz
);

ALTER TABLE public.sos_incidents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sos_incidents_select" ON public.sos_incidents;
CREATE POLICY "sos_incidents_select" ON public.sos_incidents FOR SELECT
  USING (
    public.is_admin() OR 
    triggered_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = sos_incidents.booking_id 
        AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "sos_incidents_insert" ON public.sos_incidents;
CREATE POLICY "sos_incidents_insert" ON public.sos_incidents FOR INSERT
  WITH CHECK (
    auth.uid() = triggered_by OR public.is_admin()
  );

DROP POLICY IF EXISTS "sos_incidents_update" ON public.sos_incidents;
CREATE POLICY "sos_incidents_update" ON public.sos_incidents FOR UPDATE
  USING (public.is_admin());


-- ------------------------------------------------------------------------------
-- 4. POST-TRIP EXPENSE RECONCILIATION LOGS (trip_expense_logs)
-- Record-keeping & dispute trail only — no app payments
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.trip_expense_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  category text NOT NULL CHECK (category IN ('accommodation', 'food', 'transport', 'other')),
  amount numeric NOT NULL,
  description text,
  logged_by uuid REFERENCES public.profiles(id),
  status text DEFAULT 'submitted' CHECK (status IN ('submitted', 'confirmed_by_traveller', 'disputed')),
  traveller_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.trip_expense_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trip_expense_logs_select" ON public.trip_expense_logs;
CREATE POLICY "trip_expense_logs_select" ON public.trip_expense_logs FOR SELECT
  USING (
    public.is_admin() OR 
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = trip_expense_logs.booking_id 
        AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "trip_expense_logs_insert" ON public.trip_expense_logs;
CREATE POLICY "trip_expense_logs_insert" ON public.trip_expense_logs FOR INSERT
  WITH CHECK (
    public.is_admin() OR 
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = trip_expense_logs.booking_id AND (b.agent_id = auth.uid() OR b.traveller_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "trip_expense_logs_update" ON public.trip_expense_logs;
CREATE POLICY "trip_expense_logs_update" ON public.trip_expense_logs FOR UPDATE
  USING (
    public.is_admin() OR 
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = trip_expense_logs.booking_id 
        AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
    )
  );


-- ------------------------------------------------------------------------------
-- 5. REALTIME PUBLICATIONS
-- ------------------------------------------------------------------------------
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.agent_payout_methods;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_incidents;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.payouts;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_expense_logs;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
