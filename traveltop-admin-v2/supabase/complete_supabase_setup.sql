-- =====================================================
-- TRAVELVIBE / TRAVELTOP — PURGE DEMO DATA & KEEP ONLY YOUR ACCOUNT
-- Paste this ENTIRE script into your Supabase Dashboard -> SQL Editor and click RUN ▶️
-- =====================================================

-- Delete demo accounts and associated profiles/agent details
DELETE FROM auth.identities WHERE user_id IN (
  SELECT id FROM auth.users WHERE email IN ('admin@traveltop.com', 'agent@traveltop.com', 'traveler@traveltop.com')
);

DELETE FROM public.agent_details WHERE id IN (
  SELECT id FROM public.profiles WHERE email IN ('admin@traveltop.com', 'agent@traveltop.com', 'traveler@traveltop.com')
);

DELETE FROM public.admin_users WHERE email = 'admin@traveltop.com';

DELETE FROM public.profiles WHERE email IN ('admin@traveltop.com', 'agent@traveltop.com', 'traveler@traveltop.com');

DELETE FROM auth.users WHERE email IN ('admin@traveltop.com', 'agent@traveltop.com', 'traveler@traveltop.com');

-- Ensure your Super Admin account (ganaparthimanish@gmail.com) remains active
DO $$
DECLARE
  user_admin_id UUID := 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
BEGIN
  PERFORM create_supabase_seed_user(user_admin_id, 'ganaparthimanish@gmail.com', 'Ganaparthi@123', 'super_admin', 'Manish Ganaparthi');
  
  INSERT INTO public.admin_users (id, email, full_name, role, active)
  VALUES (user_admin_id, 'ganaparthimanish@gmail.com', 'Manish Ganaparthi', 'super_admin', true)
  ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, full_name = EXCLUDED.full_name, role = EXCLUDED.role;

  RAISE NOTICE 'Demo users removed! Only ganaparthimanish@gmail.com remains active.';
END;
$$;
