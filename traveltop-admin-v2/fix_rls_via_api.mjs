/**
 * Fix RLS policies via Supabase Management API
 * This requires a SUPABASE_ACCESS_TOKEN (personal access token from supabase.com/dashboard/account/tokens)
 * 
 * Instructions:
 * 1. Go to https://supabase.com/dashboard/account/tokens
 * 2. Create a new access token
 * 3. Set it in the SUPABASE_ACCESS_TOKEN variable below
 * 4. Run: node fix_rls_via_api.mjs
 */

const SUPABASE_ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN || 'YOUR_PERSONAL_ACCESS_TOKEN_HERE';
const PROJECT_REF = 'imretkikrsdydreldosx';

const sql = `
-- Drop old restrictive policies
DROP POLICY IF EXISTS "messages_select_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_insert_participants" ON public.messages;
DROP POLICY IF EXISTS "messages_update_read" ON public.messages;

-- Allow authenticated users to read messages where they are a booking participant
CREATE POLICY "messages_select_participants" ON public.messages 
  FOR SELECT USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = booking_id 
      AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
    )
  );

-- Allow authenticated users to INSERT messages where they are a booking participant
CREATE POLICY "messages_insert_participants" ON public.messages 
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL AND
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = booking_id 
      AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
    )
  );

-- Allow update (mark as read) for booking participants
CREATE POLICY "messages_update_read" ON public.messages 
  FOR UPDATE USING (
    auth.uid() IS NOT NULL AND
    EXISTS (
      SELECT 1 FROM public.bookings b 
      WHERE b.id = booking_id 
      AND (b.traveller_id = auth.uid() OR b.agent_id = auth.uid())
    )
  );

-- Fix wishlists RLS
DROP POLICY IF EXISTS "wishlists_select_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_insert_own" ON public.wishlists;
DROP POLICY IF EXISTS "wishlists_delete_own" ON public.wishlists;

CREATE POLICY "wishlists_select_own" ON public.wishlists 
  FOR SELECT USING (auth.uid() = traveller_id);
CREATE POLICY "wishlists_insert_own" ON public.wishlists 
  FOR INSERT WITH CHECK (auth.uid() = traveller_id);
CREATE POLICY "wishlists_delete_own" ON public.wishlists 
  FOR DELETE USING (auth.uid() = traveller_id);

-- Fix products RLS to allow public read
DROP POLICY IF EXISTS "products_select_all" ON public.products;
CREATE POLICY "products_select_all" ON public.products FOR SELECT USING (true);
`;

async function applyRLS() {
  if (SUPABASE_ACCESS_TOKEN === 'YOUR_PERSONAL_ACCESS_TOKEN_HERE') {
    console.error('ERROR: Please set SUPABASE_ACCESS_TOKEN environment variable');
    console.error('Get your token from: https://supabase.com/dashboard/account/tokens');
    process.exit(1);
  }

  const response = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPABASE_ACCESS_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  });

  const data = await response.json();
  console.log('Status:', response.status);
  console.log('Response:', JSON.stringify(data, null, 2));
}

applyRLS();
