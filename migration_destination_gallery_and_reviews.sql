-- 1. DESTINATION IMAGES (Multi-cover gallery)
CREATE TABLE IF NOT EXISTS public.destination_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id uuid REFERENCES public.destinations(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_destination_images_dest ON public.destination_images(destination_id, display_order);

ALTER TABLE public.destination_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read destination_images" ON public.destination_images;
CREATE POLICY "Public read destination_images" ON public.destination_images
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin write destination_images" ON public.destination_images;
CREATE POLICY "Admin write destination_images" ON public.destination_images
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 2. DESTINATIONS RATING METRICS
ALTER TABLE public.destinations ADD COLUMN IF NOT EXISTS rating_avg numeric(3,2) DEFAULT 0.0;
ALTER TABLE public.destinations ADD COLUMN IF NOT EXISTS review_count int DEFAULT 0;

-- 3. DESTINATION REVIEWS
CREATE TABLE IF NOT EXISTS public.destination_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  destination_id uuid REFERENCES public.destinations(id) ON DELETE CASCADE,
  traveller_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  rating int NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_destination_reviews_dest ON public.destination_reviews(destination_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_destination_reviews_traveller ON public.destination_reviews(traveller_id);

ALTER TABLE public.destination_reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read destination_reviews" ON public.destination_reviews;
CREATE POLICY "Public read destination_reviews" ON public.destination_reviews
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admin delete destination_reviews" ON public.destination_reviews;
DROP POLICY IF EXISTS "Admin manage destination_reviews" ON public.destination_reviews;
CREATE POLICY "Admin manage destination_reviews" ON public.destination_reviews
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Traveller insert completed booking review" ON public.destination_reviews;
CREATE POLICY "Traveller insert completed booking review" ON public.destination_reviews
  FOR INSERT WITH CHECK (
    auth.uid() = traveller_id
    AND booking_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id
        AND b.traveller_id = auth.uid()
        AND b.status = 'completed'
    )
  );

-- 4. DESTINATION REVIEW IMAGES
CREATE TABLE IF NOT EXISTS public.destination_review_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid REFERENCES public.destination_reviews(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dest_review_images_rev ON public.destination_review_images(review_id);

ALTER TABLE public.destination_review_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read destination_review_images" ON public.destination_review_images;
CREATE POLICY "Public read destination_review_images" ON public.destination_review_images
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert destination_review_images" ON public.destination_review_images;
CREATE POLICY "Allow insert destination_review_images" ON public.destination_review_images
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.destination_reviews dr
      WHERE dr.id = review_id
        AND dr.traveller_id = auth.uid()
    )
  );

-- 5. RECALCULATE DESTINATION RATING TRIGGER
CREATE OR REPLACE FUNCTION public.recalculate_destination_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_dest_id uuid;
  v_avg numeric(3,2);
  v_count int;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_dest_id := OLD.destination_id;
  ELSE
    v_dest_id := NEW.destination_id;
  END IF;

  SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0.0), COUNT(*)
  INTO v_avg, v_count
  FROM public.destination_reviews
  WHERE destination_id = v_dest_id;

  UPDATE public.destinations
  SET rating_avg = v_avg,
      review_count = v_count
  WHERE id = v_dest_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_recalc_dest_rating ON public.destination_reviews;
CREATE TRIGGER trg_recalc_dest_rating
AFTER INSERT OR UPDATE OR DELETE ON public.destination_reviews
FOR EACH ROW EXECUTE FUNCTION public.recalculate_destination_rating();

-- 6. REALTIME PUBLICATION
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.destination_images;
  EXCEPTION WHEN duplicate_object THEN
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.destination_reviews;
  EXCEPTION WHEN duplicate_object THEN
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.destination_review_images;
  EXCEPTION WHEN duplicate_object THEN
  END;
END $$;

-- 7. STORAGE BUCKETS
INSERT INTO storage.buckets (id, name, public)
VALUES ('destination-images', 'destination-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public)
VALUES ('review-images', 'review-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public read destination-images" ON storage.objects;
CREATE POLICY "Public read destination-images" ON storage.objects
  FOR SELECT USING (bucket_id IN ('destination-images', 'review-images'));

DROP POLICY IF EXISTS "Public upload review-images" ON storage.objects;
CREATE POLICY "Public upload review-images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id IN ('destination-images', 'review-images'));
