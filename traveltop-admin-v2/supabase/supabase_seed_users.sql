-- =====================================================
-- TRAVELVIBE / TRAVELTOP — SUPABASE USER SEED SCRIPT
-- Run this in the Supabase SQL Editor to create test accounts
-- =====================================================

-- 1. Helper function to create auth user if missing
CREATE OR REPLACE FUNCTION create_supabase_seed_user(
  user_email TEXT,
  user_password TEXT,
  user_role TEXT DEFAULT 'traveller',
  user_full_name TEXT DEFAULT 'Test User'
) RETURNS UUID AS $$
DECLARE
  new_uid UUID;
BEGIN
  SELECT id INTO new_uid FROM auth.users WHERE email = user_email;

  IF new_uid IS NULL THEN
    new_uid := gen_random_uuid();
    INSERT INTO auth.users (
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at
    ) VALUES (
      new_uid,
      'authenticated',
      'authenticated',
      user_email,
      crypt(user_password, gen_salt('bf')),
      now(),
      '{"provider": "email", "providers": ["email"]}',
      jsonb_build_object('full_name', user_full_name),
      now(),
      now()
    );
  END IF;

  -- Ensure profile exists
  INSERT INTO public.profiles (id, role, full_name, email, created_at)
  VALUES (new_uid, user_role, user_full_name, user_email, now())
  ON CONFLICT (id) DO UPDATE SET role = user_role, full_name = user_full_name;

  RETURN new_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Seed Default Accounts
DO $$
DECLARE
  admin_id UUID;
  agent_id UUID;
  traveller_id UUID;
BEGIN
  -- Super Admin: admin@traveltop.com / Admin@123
  admin_id := create_supabase_seed_user('admin@traveltop.com', 'Admin@123', 'super_admin', 'Super Admin');
  INSERT INTO public.admin_users (id, email, full_name, role, active)
  VALUES (admin_id, 'admin@traveltop.com', 'Super Admin', 'super_admin', true)
  ON CONFLICT (id) DO NOTHING;

  -- Local Agent: agent@traveltop.com / Agent@123
  agent_id := create_supabase_seed_user('agent@traveltop.com', 'Agent@123', 'agent', 'Priya Sharma');
  INSERT INTO public.agent_details (
    id, bio, years_experience, languages, places_covered, price_per_day, verified, verification_status
  ) VALUES (
    agent_id,
    'Certified Himalayan trekking & local heritage guide with 8 years experience.',
    8,
    ARRAY['English', 'Hindi'],
    ARRAY['Manali', 'Spiti', 'Shimla'],
    2500,
    true,
    'approved'
  ) ON CONFLICT (id) DO UPDATE SET verification_status = 'approved', verified = true;

  -- Traveler: traveler@traveltop.com / Traveler@123
  traveller_id := create_supabase_seed_user('traveler@traveltop.com', 'Traveler@123', 'traveller', 'Alex Traveler');

  RAISE NOTICE 'Successfully seeded Admin (admin@traveltop.com), Agent (agent@traveltop.com), and Traveler (traveler@traveltop.com)!';
END;
$$;
