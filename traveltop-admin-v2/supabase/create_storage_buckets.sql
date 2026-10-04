-- Create Supabase storage buckets for images (run in SQL Editor)

-- Create destination-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('destination-images', 'destination-images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- Create place-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('place-images', 'place-images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow all authenticated users to upload to both buckets
DROP POLICY IF EXISTS "destination-images public read" ON storage.objects;
DROP POLICY IF EXISTS "destination-images upload" ON storage.objects;
DROP POLICY IF EXISTS "place-images public read" ON storage.objects;
DROP POLICY IF EXISTS "place-images upload" ON storage.objects;

CREATE POLICY "destination-images public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'destination-images');

CREATE POLICY "destination-images upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'destination-images' AND auth.role() = 'authenticated');

CREATE POLICY "destination-images delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'destination-images' AND auth.role() = 'authenticated');

CREATE POLICY "place-images public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'place-images');

CREATE POLICY "place-images upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'place-images' AND auth.role() = 'authenticated');

CREATE POLICY "place-images delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'place-images' AND auth.role() = 'authenticated');
