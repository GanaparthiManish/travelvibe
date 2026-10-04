-- ============================================================
-- TRAVELVIBE — FIX STORAGE BUCKETS + CLEAN STALE AGENT DATA
-- Run this in: Supabase Dashboard -> SQL Editor -> New Query -> RUN ▶️
-- ============================================================

-- STEP 1: Create/Fix all 3 storage buckets
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'agent-gallery', 'agent-gallery', true, 10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 10485760;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars', 'avatars', true, 5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET public = true, file_size_limit = 5242880;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'verification-docs', 'verification-docs', false, 10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
) ON CONFLICT (id) DO UPDATE SET public = false, file_size_limit = 10485760;


-- STEP 2: Drop all old conflicting storage RLS policies
-- ============================================================
DROP POLICY IF EXISTS "public_read_agent_gallery" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_agent_gallery" ON storage.objects;
DROP POLICY IF EXISTS "auth_update_agent_gallery" ON storage.objects;
DROP POLICY IF EXISTS "public_read_avatars" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_avatars" ON storage.objects;
DROP POLICY IF EXISTS "auth_update_avatars" ON storage.objects;
DROP POLICY IF EXISTS "agent_upload_verification_docs" ON storage.objects;
DROP POLICY IF EXISTS "admin_read_verification_docs" ON storage.objects;
DROP POLICY IF EXISTS "agent_update_verification_docs" ON storage.objects;


-- STEP 3: Create open (permissive) storage RLS policies for agent uploads
-- ============================================================

-- Agent Gallery bucket: public read, anyone (incl. mobile agents) can insert/update
CREATE POLICY "public_read_agent_gallery" ON storage.objects
  FOR SELECT USING (bucket_id = 'agent-gallery');

CREATE POLICY "auth_upload_agent_gallery" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'agent-gallery');

CREATE POLICY "auth_update_agent_gallery" ON storage.objects
  FOR UPDATE USING (bucket_id = 'agent-gallery');


-- Avatars bucket: public read, anyone can insert/update
CREATE POLICY "public_read_avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "auth_upload_avatars" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "auth_update_avatars" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars');


-- Verification Docs bucket: anyone can upload, anyone can read (admin views via signed URL)
CREATE POLICY "agent_upload_verification_docs" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'verification-docs');

CREATE POLICY "admin_read_verification_docs" ON storage.objects
  FOR SELECT USING (bucket_id = 'verification-docs');

CREATE POLICY "agent_update_verification_docs" ON storage.objects
  FOR UPDATE USING (bucket_id = 'verification-docs');


-- STEP 4: Clean up stale "Agent Guide" dummy profile (if still there)
-- This updates any profile still showing "Agent Guide" name
-- ============================================================
UPDATE public.profiles
SET full_name = 'Unknown Agent'
WHERE full_name = 'Agent Guide' AND email = 'agent@traveltop.com';

-- Also delete the stale agent_details row tied to the dummy email
-- so the real signup shows correctly
DELETE FROM public.agent_details
WHERE id IN (
  SELECT id FROM public.profiles
  WHERE email = 'agent@traveltop.com' AND full_name IN ('Agent Guide', 'Unknown Agent')
);

DELETE FROM public.profiles
WHERE email = 'agent@traveltop.com' AND full_name IN ('Agent Guide', 'Unknown Agent');
