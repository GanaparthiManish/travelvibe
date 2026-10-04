-- ====================================================================
-- OPTIONAL: ADD FLEXIBLE PRICING COLUMNS TO BOOKINGS TABLE
-- ====================================================================
-- Run this in your Supabase SQL Editor if you wish to store itemized add-ons
-- as dedicated JSONB/Numeric columns in public.bookings:

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS base_price numeric;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS selected_addons jsonb;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS negotiated_price numeric;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
