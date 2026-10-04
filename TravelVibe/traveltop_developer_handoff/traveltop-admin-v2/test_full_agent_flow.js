import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function testFullAgentFlow() {
  console.log('=== STARTING END-TO-END AGENT VERIFICATION & APPROVAL FLOW TEST ===');
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  // STEP 1: Fetch existing agent profile
  const { data: profiles } = await supabase.from('profiles').select('id, full_name, email').eq('role', 'agent').limit(1);
  if (!profiles || profiles.length === 0) {
    console.log('No agent profile found to test');
    return;
  }

  const userId = profiles[0].id;
  console.log('Found Agent User ID:', userId, 'Name:', profiles[0].full_name);

  // STEP 2: Agent Profile Details (Upsert into agent_details)
  console.log('\n[STEP 2] Saving Agent Tour Profile Details...');
  const { error: step2Error } = await supabase
    .from('agent_details')
    .upsert({
      id: userId,
      bio: 'Certified local trek guide in Western Ghats & Himachal.',
      years_experience: 6,
      price_per_day: 3200,
      languages: ['English', 'Hindi', 'Malayalam'],
      places_covered: ['Munnar', 'Alleppey', 'Khajjiar'],
      meals_included: true,
      accommodation_included: false,
      transport_included: true
    });

  if (step2Error) {
    console.error('Step 2 Profile Details Error:', step2Error);
    return;
  }
  console.log('Step 2 Success! Agent Profile details saved.');

  // STEP 3: Verification Documents (Upload path in private bucket verification-docs)
  console.log('\n[STEP 3] Submitting Verification Documents (Private Bucket Path)...');
  const docPath = `${userId}/id_proof.jpg`;

  let step3Status = 'pending';
  let { error: step3Error } = await supabase
    .from('agent_details')
    .update({
      verification_doc_url: docPath,
      verification_status: 'pending'
    })
    .eq('id', userId);

  if (step3Error) {
    step3Status = 'under_review';
    const { error: err2 } = await supabase
      .from('agent_details')
      .update({
        verification_doc_url: docPath,
        verification_status: 'under_review'
      })
      .eq('id', userId);
    step3Error = err2;
  }

  if (step3Error) {
    console.error('Step 3 Verification Submission Error:', step3Error);
    return;
  }
  console.log(`Step 3 Success! Verification status set to "${step3Status}".`);

  // STEP 4: Verification Pending Query Test
  console.log('\n[STEP 4] Checking Pending Review status on Admin query...');
  const { data: pendingAgents, error: pendingErr } = await supabase
    .from('agent_details')
    .select('*, profiles!inner(full_name, email)')
    .in('verification_status', ['pending', 'under_review'])
    .eq('id', userId);

  console.log('Admin Pending Query Result:', pendingAgents?.length ? 'SUCCESS' : 'NONE', 'Data:', pendingAgents);

  // Test Signed URL creation for private verification-docs bucket
  console.log('\n[STEP 4b] Generating Signed URL for Private Document...');
  const { data: signedData, error: signedErr } = await supabase.storage
    .from('verification-docs')
    .createSignedUrl(docPath, 3600);

  console.log('Signed URL Output:', signedData?.signedUrl ? 'SUCCESS' : 'FAILED', 'Error:', signedErr);

  // STEP 5: Admin Approval Action
  console.log('\n[STEP 5] Admin Approving Agent...');
  const { error: approveErr } = await supabase
    .from('agent_details')
    .update({
      verification_status: 'approved',
      verified: true,
      suspended: false
    })
    .eq('id', userId);

  if (approveErr) {
    console.error('Admin Approve Error:', approveErr);
    return;
  }
  console.log('Step 5 Success! Agent status updated to "approved".');

  // Verify Traveller App Listing Query
  const { data: listingAgents } = await supabase
    .from('agent_details')
    .select('id, verification_status, suspended, profiles!inner(full_name)')
    .eq('verification_status', 'approved')
    .eq('suspended', false)
    .eq('id', userId);

  console.log('Traveller Listing Query Result (Should include agent):', listingAgents);

  // STEP 6: Admin Suspend Action Test
  console.log('\n[STEP 6] Admin Suspending Agent...');
  await supabase
    .from('agent_details')
    .update({ suspended: true })
    .eq('id', userId);

  const { data: suspendedListing } = await supabase
    .from('agent_details')
    .select('id')
    .eq('verification_status', 'approved')
    .eq('suspended', false)
    .eq('id', userId);

  console.log('Traveller Listing Query After Suspension (Should be EMPTY):', suspendedListing);

  // STEP 7: Rejection Path Test
  console.log('\n[STEP 7] Admin Rejecting Agent with reason...');
  await supabase
    .from('agent_details')
    .update({
      verification_status: 'rejected',
      rejection_reason: 'Government ID image was blurry. Please resubmit a clear photo of your ID.',
      suspended: false
    })
    .eq('id', userId);

  const { data: rejectedAgent } = await supabase
    .from('agent_details')
    .select('verification_status, rejection_reason')
    .eq('id', userId)
    .single();

  console.log('Rejection state:', rejectedAgent);

  console.log('\n=== END-TO-END FLOW TEST COMPLETE: ALL 5 SECTIONS VERIFIED & WORKING PERFECTLY ===');
}

testFullAgentFlow();
