-- ============================================================
-- SEED: Sub-Places for "Valley of Flowers" destination
-- Run in Supabase SQL Editor
-- ============================================================

-- Step 1: Find Valley of Flowers destination id
-- (We use a DO block so we can reference the id dynamically)
DO $$
DECLARE
  v_dest_id uuid;
BEGIN

  -- Get the Valley of Flowers destination id (case-insensitive)
  SELECT id INTO v_dest_id
  FROM public.destinations
  WHERE name ILIKE '%valley of flowers%'
  LIMIT 1;

  IF v_dest_id IS NULL THEN
    RAISE EXCEPTION 'Valley of Flowers destination not found. Please create it in the Destinations page first.';
  END IF;

  -- Delete existing sub-places for this destination to avoid duplicates
  DELETE FROM public.places WHERE destination_id = v_dest_id;

  -- Insert 5 sub-places
  INSERT INTO public.places (destination_id, name, category, ideal_duration, best_time_of_day, description, display_order)
  VALUES

  (
    v_dest_id,
    'Valley of Flowers National Park',
    'Nature',
    'Full day (6-8 hours round trip from Ghangaria)',
    'Early morning (7-8 AM start)',
    'The main valley trail — a roughly 6 km trek one-way from Ghangaria through meadows bursting with color, waterfalls, and glacial streams. The bloom composition changes almost weekly, so late July looks different from late August. No camping allowed inside; must return to Ghangaria by evening.',
    1
  ),

  (
    v_dest_id,
    'Hemkund Sahib',
    'Religious',
    'Full day (steep trek, best as a separate day from Valley trek)',
    'Early morning (temple closes by early afternoon)',
    'A revered Sikh pilgrimage site at 4,300m, centered on a glacial lake believed to be where Guru Gobind Singh meditated in a previous life. The trek from Ghangaria is steep and often combined with a Valley of Flowers trip since both start from the same base village.',
    2
  ),

  (
    v_dest_id,
    'Ghangaria (Base Village)',
    'Nature',
    'Half day (arrival/departure buffer, acclimatization)',
    'Evening (rest before early treks)',
    'The only base village for both Valley of Flowers and Hemkund Sahib treks, reachable by a 14 km trek or mule ride from Govindghat. All guesthouses and permit checkpoints are here — no accommodation exists inside the valley itself.',
    3
  ),

  (
    v_dest_id,
    'Pushpawati River & Waterfalls',
    'Nature',
    'Included within the main valley trek (add 1 hour for photography stops)',
    'Midday (best light on the glacial water)',
    'A glacial river running through the valley floor, fed by multiple waterfalls cascading from the surrounding peaks — one of the most photographed features within the valley, especially where wildflowers cluster along its banks.',
    4
  ),

  (
    v_dest_id,
    'Govindghat',
    'Historical',
    'Few hours (starting/ending point)',
    'Morning (start of trek)',
    'The road-accessible town where the trek to Ghangaria begins, situated at the confluence of the Alaknanda and Bhyundar rivers. Most travellers arrive here by road from Rishikesh/Joshimath before starting the trek.',
    5
  );

  RAISE NOTICE 'Successfully inserted 5 sub-places for Valley of Flowers (destination_id: %)', v_dest_id;

END $$;

-- Step 2: Verify
SELECT
  p.name,
  p.category,
  p.ideal_duration,
  p.best_time_of_day,
  p.display_order
FROM public.places p
JOIN public.destinations d ON d.id = p.destination_id
WHERE d.name ILIKE '%valley of flowers%'
ORDER BY p.display_order;
