-- ============================================================
-- ONE-TIME FIX: Create clean confirmed test agent
-- Paste in Supabase SQL Editor → Run ▶️
-- ============================================================
DO $$
DECLARE
  v_uid UUID;
BEGIN
  -- 1. Upsert into auth.users (email_confirmed_at = now means no confirmation needed)
  INSERT INTO auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at, confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated', 'authenticated',
    'testagent@traveltop.com',
    crypt('Test@1234', gen_salt('bf')),
    now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"full_name":"Test Agent","role":"agent"}'::jsonb,
    now(), now()
  )
  ON CONFLICT (email) DO UPDATE SET
    encrypted_password = crypt('Test@1234', gen_salt('bf')),
    email_confirmed_at  = now(),
    confirmed_at        = now();

  -- 2. Get the user id
  SELECT id INTO v_uid FROM auth.users WHERE email = 'testagent@traveltop.com';

  -- 3. Ensure auth.identities row exists
  INSERT INTO auth.identities (
    id, user_id, provider_id, identity_data, provider, created_at, updated_at, last_sign_in_at
  ) VALUES (
    gen_random_uuid(), v_uid, 'testagent@traveltop.com',
    jsonb_build_object('sub', v_uid::text, 'email', 'testagent@traveltop.com'),
    'email', now(), now(), now()
  ) ON CONFLICT DO NOTHING;

  -- 4. Ensure profile row
  INSERT INTO public.profiles (id, email, full_name, role, phone)
  VALUES (v_uid, 'testagent@traveltop.com', 'Test Agent', 'agent', '9999999999')
  ON CONFLICT (id) DO UPDATE SET
    full_name = 'Test Agent', role = 'agent',
    email = 'testagent@traveltop.com';

  -- 5. Ensure agent_details with APPROVED status
  INSERT INTO public.agent_details (
    id, bio, years_experience, price_per_day, languages,
    places_covered, meals_included, accommodation_included,
    transport_included, verification_status, verified, suspended
  ) VALUES (
    v_uid, 'Experienced local eco-tour guide in Assam.', 5, 2500,
    ARRAY['English','Hindi'],
    ARRAY['Assam','Meghalaya'],
    true, false, true,
    'approved', true, false
  )
  ON CONFLICT (id) DO UPDATE SET
    verification_status = 'approved',
    verified            = true,
    suspended           = false;

  RAISE NOTICE '✅ Test agent ready → testagent@traveltop.com / Test@1234  (uid: %)', v_uid;
END $$;
