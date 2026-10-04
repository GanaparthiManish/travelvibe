-- =====================================================================
-- 3-TIER MEDIA & DOCUMENT SYSTEM FOR TRAVELVIBE / TRAVELTOP
-- =====================================================================

-- 1. Create agent_gallery table (Public-facing portfolio)
CREATE TABLE IF NOT EXISTS public.agent_gallery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS on agent_gallery
ALTER TABLE public.agent_gallery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_gallery_select_public" ON public.agent_gallery;
DROP POLICY IF EXISTS "agent_gallery_insert_own" ON public.agent_gallery;
DROP POLICY IF EXISTS "agent_gallery_update_own" ON public.agent_gallery;
DROP POLICY IF EXISTS "agent_gallery_delete_own" ON public.agent_gallery;

CREATE POLICY "agent_gallery_select_public" ON public.agent_gallery
  FOR SELECT USING (true);

CREATE POLICY "agent_gallery_insert_own" ON public.agent_gallery
  FOR INSERT WITH CHECK (auth.uid() = agent_id OR public.is_admin() OR auth.role() = 'authenticated');

CREATE POLICY "agent_gallery_update_own" ON public.agent_gallery
  FOR UPDATE USING (auth.uid() = agent_id OR public.is_admin());

CREATE POLICY "agent_gallery_delete_own" ON public.agent_gallery
  FOR DELETE USING (auth.uid() = agent_id OR public.is_admin());


-- 2. Create agent_documents table (Private admin-only verification docs)
CREATE TABLE IF NOT EXISTS public.agent_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  document_type text NOT NULL, -- 'id_proof', 'license', 'selfie'
  file_url text NOT NULL,
  uploaded_at timestamptz DEFAULT now()
);

-- Enable RLS on agent_documents
ALTER TABLE public.agent_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "agent_documents_select_restricted" ON public.agent_documents;
DROP POLICY IF EXISTS "agent_documents_insert_own" ON public.agent_documents;

CREATE POLICY "agent_documents_select_restricted" ON public.agent_documents
  FOR SELECT USING (auth.uid() = agent_id OR public.is_admin() OR auth.role() = 'service_role');

CREATE POLICY "agent_documents_insert_own" ON public.agent_documents
  FOR INSERT WITH CHECK (auth.uid() = agent_id OR public.is_admin() OR auth.role() = 'authenticated');


-- 3. Storage Bucket: agent-gallery (PUBLIC)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'agent-gallery',
  'agent-gallery',
  true, -- PUBLIC BUCKET
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "public_read_agent_gallery" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_agent_gallery" ON storage.objects;

CREATE POLICY "public_read_agent_gallery" ON storage.objects
  FOR SELECT USING (bucket_id = 'agent-gallery');

CREATE POLICY "auth_upload_agent_gallery" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'agent-gallery' AND (auth.role() = 'authenticated' OR auth.role() = 'anon')
  );


-- 4. Storage Bucket: avatars (PUBLIC)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true, -- PUBLIC BUCKET
  5242880, -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "public_read_avatars" ON storage.objects;
DROP POLICY IF EXISTS "auth_upload_avatars" ON storage.objects;

CREATE POLICY "public_read_avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "auth_upload_avatars" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND (auth.role() = 'authenticated' OR auth.role() = 'anon')
  );


-- 5. Confirm verification-docs remains PRIVATE (public = false)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'verification-docs',
  'verification-docs',
  false, -- PRIVATE BUCKET
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET public = false;
