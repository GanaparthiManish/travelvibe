-- =====================================================
-- TRAVELTOP — COMPLETE AGENT VERIFICATION & RLS SETUP
-- Run this script in your Supabase Dashboard -> SQL Editor
-- =====================================================

-- 1. Automatic Profile Creation Trigger on auth.users (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Auto-confirm user email so no email verification link is required
  UPDATE auth.users 
  SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
      confirmed_at = COALESCE(confirmed_at, now())
  WHERE id = new.id AND email_confirmed_at IS NULL;

  INSERT INTO public.profiles (id, full_name, email, role, phone)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    COALESCE(new.raw_user_meta_data->>'role', 'agent'),
    new.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
    email = COALESCE(EXCLUDED.email, public.profiles.email),
    role = COALESCE(EXCLUDED.role, public.profiles.role),
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Ensure Full Replica Identity for Supabase Realtime CDC broadcasting
ALTER TABLE public.agent_details REPLICA IDENTITY FULL;

-- 2. Drop old check constraints if restricted
ALTER TABLE public.agent_details DROP CONSTRAINT IF EXISTS agent_details_verification_status_check;
ALTER TABLE public.agent_details ADD CONSTRAINT agent_details_verification_status_check 
  CHECK (verification_status IN ('pending', 'under_review', 'approved', 'rejected'));

-- 3. Ensure columns exist on agent_details
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS id_proof_url text;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS license_url text;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS selfie_url text;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS verification_doc_url text;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS verification_status text DEFAULT 'pending';
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS rejection_reason text;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS verified boolean DEFAULT false;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS suspended boolean DEFAULT false;
ALTER TABLE public.agent_details ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- 4. Ensure columns exist on profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone text;

-- 5. Create PRIVATE Storage Bucket for Verification Docs
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'verification-docs',
  'verification-docs',
  false, -- PRIVATE BUCKET
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET public = false;

-- 6. Storage Policies for verification-docs
DROP POLICY IF EXISTS "owner_admin_read_verification_docs" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_verification_docs" ON storage.objects;
DROP POLICY IF EXISTS "owner_admin_delete_verification_docs" ON storage.objects;

CREATE POLICY "owner_admin_read_verification_docs" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'verification-docs' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin()
      OR auth.role() = 'service_role'
    )
  );

CREATE POLICY "auth_upload_verification_docs" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'verification-docs' AND auth.role() = 'authenticated'
  );

CREATE POLICY "owner_admin_delete_verification_docs" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'verification-docs' AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR public.is_admin()
    )
  );

-- 7. Row Level Security on profiles & agent_details
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;

CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id OR public.is_admin());
CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "agent_details_select_all" ON public.agent_details;
DROP POLICY IF EXISTS "agent_details_insert_own" ON public.agent_details;
DROP POLICY IF EXISTS "agent_details_update_own_or_admin" ON public.agent_details;

CREATE POLICY "agent_details_select_all" ON public.agent_details FOR SELECT USING (true);
CREATE POLICY "agent_details_insert_own" ON public.agent_details FOR INSERT WITH CHECK (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated');
CREATE POLICY "agent_details_update_own_or_admin" ON public.agent_details FOR UPDATE USING (auth.uid() = id OR public.is_admin() OR auth.role() = 'authenticated');

-- 8. Safe Realtime Publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_rel 
    WHERE prpubid = (SELECT oid FROM pg_publication WHERE pubname = 'supabase_realtime')
      AND prrelid = 'public.agent_details'::regclass
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.agent_details;
  END IF;
END;
$$;
