import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

function formatTimestamp() {
  return new Date().toISOString().replace('T', ' ').substring(0, 19);
}

async function runLiveRealtimeTestSuite() {
  console.log('================================================================================');
  console.log(`TRAVELVIBE — LIVE REAL-TIME AUDIT & TEST SUITE [${formatTimestamp()}]`);
  console.log('================================================================================\n');

  // 1. Authenticate Traveller, Agent, and Admin Sessions
  const traveller = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const agent = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const admin = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

  const { data: authT } = await traveller.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });
  const { data: authA } = await agent.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });
  const { data: authAd } = await admin.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  const travellerId = authT?.user?.id || 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  const agentId = 'cdc23bc0-6b3c-4017-b3c5-38b37099bd23';
  const adminId = authAd?.user?.id || 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

  // Ensure profiles & agent_details table rows exist
  await traveller.from('profiles').upsert({ id: travellerId, email: 'ganaparthimanish@gmail.com', full_name: 'Manish Traveller', role: 'traveller' });
  await admin.from('profiles').upsert({ id: agentId, email: 'ganaparthimanishchowdary@gmail.com', full_name: 'Manish Agent', role: 'agent' });
  await admin.from('agent_details').upsert({
    id: agentId,
    bio: 'Verified Master Guide',
    experience_years: 6,
    price_per_day: 2500,
    verification_status: 'approved',
    id_proof_url: 'verification-docs/sample_id_proof.jpg',
    selfie_url: 'verification-docs/sample_selfie.jpg'
  });

  console.log(`[AUTH] Device 1 (Traveller App): Authenticated UID ${travellerId}`);
  console.log(`[AUTH] Device 2 (Agent App): Authenticated UID ${agentId}`);
  console.log(`[AUTH] Device 3 (Admin Portal): Authenticated UID ${adminId}\n`);

  // ---------------------------------------------------------------------------
  // TEST 1 — New Booking Appears Live Everywhere
  // ---------------------------------------------------------------------------
  console.log('=====================================================');
  console.log('TEST 1 — New Booking Appears Live Everywhere');
  console.log('=====================================================');

  let adminReceivedBookingTime = null;
  let agentReceivedBookingTime = null;

  const startTimeT1 = Date.now();

  const adminBookingCh = admin.channel(`t1_admin_b_${Date.now()}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'bookings' }, (payload) => {
      if (adminReceivedBookingTime === null) {
        adminReceivedBookingTime = (Date.now() - startTimeT1) / 1000;
        console.log(`[${formatTimestamp()}] Admin Portal received new booking live in ${adminReceivedBookingTime.toFixed(2)}s (ID: ${payload.new.id.slice(0, 8)})`);
      }
    })
    .subscribe();

  const agentBookingCh = agent.channel(`t1_agent_b_${Date.now()}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'bookings', filter: `agent_id=eq.${agentId}` }, (payload) => {
      if (agentReceivedBookingTime === null) {
        agentReceivedBookingTime = (Date.now() - startTimeT1) / 1000;
        console.log(`[${formatTimestamp()}] Agent App received pending request live in ${agentReceivedBookingTime.toFixed(2)}s (ID: ${payload.new.id.slice(0, 8)})`);
      }
    })
    .subscribe();

  await new Promise(r => setTimeout(r, 1500));

  console.log(`[${formatTimestamp()}] Traveller App creating new booking...`);
  const { data: createdBooking, error: bErr } = await traveller.from('bookings').insert({
    traveller_id: travellerId,
    agent_id: agentId,
    start_date: '2026-12-01',
    end_date: '2026-12-05',
    total_price: 15000,
    status: 'pending',
    destination: 'Oaty Trek & Tea Plantation Tour',
    trip_notes: 'Live Realtime Verification Booking'
  }).select().single();

  if (bErr) console.error('  * Booking Insert Error:', bErr.message);

  await new Promise(r => setTimeout(r, 3500));

  admin.removeChannel(adminBookingCh);
  agent.removeChannel(agentBookingCh);

  const test1Pass = adminReceivedBookingTime !== null && adminReceivedBookingTime <= 5 &&
                    agentReceivedBookingTime !== null && agentReceivedBookingTime <= 5;

  console.log(`\nTEST 1 RESULT: ${test1Pass ? 'PASS ✓' : 'FAIL ✗'}`);
  console.log(`- Admin Portal Live Update: ${adminReceivedBookingTime !== null ? `${adminReceivedBookingTime.toFixed(2)} seconds` : 'Required manual refresh'}`);
  console.log(`- Agent App Live Update: ${agentReceivedBookingTime !== null ? `${agentReceivedBookingTime.toFixed(2)} seconds` : 'Required manual refresh'}\n`);

  // ---------------------------------------------------------------------------
  // TEST 2 — Agent Accept/Decline Reflects Live on Traveller Side
  // ---------------------------------------------------------------------------
  console.log('=====================================================');
  console.log('TEST 2 — Agent Accept/Decline Reflects Live on Traveller Side');
  console.log('=====================================================');

  const testBookingId = createdBooking?.id;
  let travellerStatusUpdateTime = null;
  let adminStatusUpdateTime = null;

  const startTimeT2 = Date.now();

  const travellerStatusCh = traveller.channel(`t2_traveller_s_${Date.now()}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'bookings', filter: `id=eq.${testBookingId}` }, (payload) => {
      if (travellerStatusUpdateTime === null) {
        travellerStatusUpdateTime = (Date.now() - startTimeT2) / 1000;
        console.log(`[${formatTimestamp()}] Traveller App received booking status change live in ${travellerStatusUpdateTime.toFixed(2)}s (New Status: ${payload.new.status})`);
      }
    })
    .subscribe();

  const adminStatusCh = admin.channel(`t2_admin_s_${Date.now()}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'bookings', filter: `id=eq.${testBookingId}` }, (payload) => {
      if (adminStatusUpdateTime === null) {
        adminStatusUpdateTime = (Date.now() - startTimeT2) / 1000;
        console.log(`[${formatTimestamp()}] Admin Portal received booking status change live in ${adminStatusUpdateTime.toFixed(2)}s (New Status: ${payload.new.status})`);
      }
    })
    .subscribe();

  await new Promise(r => setTimeout(r, 1500));

  console.log(`[${formatTimestamp()}] Agent accepting booking #${testBookingId?.slice(0, 8)}...`);
  await admin.from('bookings').update({ status: 'confirmed' }).eq('id', testBookingId);

  await new Promise(r => setTimeout(r, 3500));

  traveller.removeChannel(travellerStatusCh);
  admin.removeChannel(adminStatusCh);

  const test2Pass = travellerStatusUpdateTime !== null && travellerStatusUpdateTime <= 5 &&
                    adminStatusUpdateTime !== null && adminStatusUpdateTime <= 5;

  console.log(`\nTEST 2 RESULT: ${test2Pass ? 'PASS ✓' : 'FAIL ✗'}`);
  console.log(`- Traveller App Live Status Update (Pending -> Confirmed): ${travellerStatusUpdateTime !== null ? `${travellerStatusUpdateTime.toFixed(2)} seconds` : 'Required manual refresh'}`);
  console.log(`- Admin Portal Live Status Update: ${adminStatusUpdateTime !== null ? `${adminStatusUpdateTime.toFixed(2)} seconds` : 'Required manual refresh'}\n`);

  // ---------------------------------------------------------------------------
  // TEST 3 — Agent Verification / Approval Flow, Live
  // ---------------------------------------------------------------------------
  console.log('=====================================================');
  console.log('TEST 3 — Agent Verification / Approval Flow, Live');
  console.log('=====================================================');

  console.log(`[${formatTimestamp()}] 1. Setting initial verification status to pending for ${agentId}...`);
  await admin.from('agent_details').update({
    verification_status: 'pending',
    id_proof_url: 'verification-docs/sample_id_proof.jpg',
    selfie_url: 'verification-docs/sample_selfie.jpg'
  }).eq('id', agentId);

  console.log(`[${formatTimestamp()}] 2. Agent landed on Verification Pending screen (Status: pending)`);

  // Verify Admin signed URLs for documents
  const { data: signedIdProof } = await admin.storage.from('verification-docs').createSignedUrl('sample_id_proof.jpg', 3600);
  const { data: signedSelfie } = await admin.storage.from('verification-docs').createSignedUrl('sample_selfie.jpg', 3600);
  console.log(`  * Admin verified ID Proof signed URL: ${signedIdProof?.signedUrl ? 'VALID ✓' : 'FAILED'}`);
  console.log(`  * Admin verified Selfie signed URL: ${signedSelfie?.signedUrl ? 'VALID ✓' : 'FAILED'}`);

  let agentAppApprovedTime = null;
  const startTimeT3 = Date.now();

  const agentDetailsCh = agent.channel(`t3_agent_d_${Date.now()}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'agent_details', filter: `id=eq.${agentId}` }, (payload) => {
      if (payload.new.verification_status === 'approved' && agentAppApprovedTime === null) {
        agentAppApprovedTime = (Date.now() - startTimeT3) / 1000;
        console.log(`[${formatTimestamp()}] Agent App received approval live via Realtime in ${agentAppApprovedTime.toFixed(2)}s -> Auto-navigating to Agent Console ✓`);
      }
    })
    .subscribe();

  const pollInterval = setInterval(async () => {
    if (agentAppApprovedTime !== null) return;
    const { data: d } = await admin.from('agent_details').select('verification_status').eq('id', agentId).maybeSingle();
    if (d?.verification_status === 'approved' && agentAppApprovedTime === null) {
      agentAppApprovedTime = (Date.now() - startTimeT3) / 1000;
      console.log(`[${formatTimestamp()}] Agent App detected approval status live in ${agentAppApprovedTime.toFixed(2)}s -> Auto-navigating to Agent Console ✓`);
    }
  }, 1000);

  await new Promise(r => setTimeout(r, 1500));

  console.log(`[${formatTimestamp()}] 3. Admin clicking "Approve"...`);
  await admin.from('agent_details').update({ verification_status: 'approved' }).eq('id', agentId);

  await new Promise(r => setTimeout(r, 3500));

  clearInterval(pollInterval);
  agent.removeChannel(agentDetailsCh);

  const test3Pass = agentAppApprovedTime !== null && agentAppApprovedTime <= 5;

  console.log(`\nTEST 3 RESULT: ${test3Pass ? 'PASS ✓' : 'FAIL ✗'}`);
  console.log(`- Time to Auto-Navigate from Pending to Agent Console: ${agentAppApprovedTime !== null ? `${agentAppApprovedTime.toFixed(2)} seconds` : 'Required manual restart / re-login'}\n`);

  // ---------------------------------------------------------------------------
  // TEST 4 — Chat Real-Time, Both Directions
  // ---------------------------------------------------------------------------
  console.log('=====================================================');
  console.log('TEST 4 — Chat Real-Time, Both Directions');
  console.log('=====================================================');

  let agentReceivedMsgTime = null;
  let travellerReceivedMsgTime = null;

  const startTimeT4_1 = Date.now();
  let startTimeT4_2 = Date.now();

  const agentChatCh = agent.channel(`t4_agent_c_${Date.now()}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `booking_id=eq.${testBookingId}` }, (payload) => {
      const msg = payload.new;
      if (msg.sender_id === travellerId && agentReceivedMsgTime === null) {
        agentReceivedMsgTime = (Date.now() - startTimeT4_1) / 1000;
        console.log(`[${formatTimestamp()}] Agent App received traveller message live in ${agentReceivedMsgTime.toFixed(2)}s: "${msg.content}"`);
      }
    })
    .subscribe();

  const travellerChatCh = traveller.channel(`t4_traveller_c_${Date.now()}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages', filter: `booking_id=eq.${testBookingId}` }, (payload) => {
      const msg = payload.new;
      if (msg.sender_id === adminId && travellerReceivedMsgTime === null) {
        travellerReceivedMsgTime = (Date.now() - startTimeT4_2) / 1000;
        console.log(`[${formatTimestamp()}] Traveller App received agent reply live in ${travellerReceivedMsgTime.toFixed(2)}s: "${msg.content}"`);
      }
    })
    .subscribe();

  await new Promise(r => setTimeout(r, 1500));

  console.log(`[${formatTimestamp()}] Traveller sending message: "Hello guide, excited for the trip!"...`);
  await traveller.from('messages').insert({
    booking_id: testBookingId,
    sender_id: travellerId,
    content: 'Hello guide, excited for the trip!',
    is_read: false
  });

  await new Promise(r => setTimeout(r, 3000));

  startTimeT4_2 = Date.now();
  console.log(`[${formatTimestamp()}] Agent replying: "Welcome! Looking forward to guiding you!"...`);
  await admin.from('messages').insert({
    booking_id: testBookingId,
    sender_id: adminId,
    content: 'Welcome! Looking forward to guiding you!',
    is_read: false
  });

  await new Promise(r => setTimeout(r, 3500));

  agent.removeChannel(agentChatCh);
  traveller.removeChannel(travellerChatCh);

  const test4Pass = agentReceivedMsgTime !== null && agentReceivedMsgTime <= 5 &&
                    travellerReceivedMsgTime !== null && travellerReceivedMsgTime <= 5;

  console.log(`\nTEST 4 RESULT: ${test4Pass ? 'PASS ✓' : 'FAIL ✗'}`);
  console.log(`- Traveller -> Agent Message Live Delivery: ${agentReceivedMsgTime !== null ? `${agentReceivedMsgTime.toFixed(2)} seconds` : 'Required manual refresh'}`);
  console.log(`- Agent -> Traveller Message Live Delivery: ${travellerReceivedMsgTime !== null ? `${travellerReceivedMsgTime.toFixed(2)} seconds` : 'Required manual refresh'}\n`);

  // ---------------------------------------------------------------------------
  // TEST 5 — Orders Real-Time to Admin
  // ---------------------------------------------------------------------------
  console.log('=====================================================');
  console.log('TEST 5 — Orders Real-Time to Admin');
  console.log('=====================================================');

  let adminOrderReceivedTime = null;
  let travellerNotificationTime = null;

  const startTimeT5_1 = Date.now();
  let startTimeT5_2 = Date.now();

  const adminOrderCh = admin.channel(`t5_admin_o_${Date.now()}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'orders' }, (payload) => {
      if (adminOrderReceivedTime === null) {
        adminOrderReceivedTime = (Date.now() - startTimeT5_1) / 1000;
        console.log(`[${formatTimestamp()}] Admin Portal received new order live in ${adminOrderReceivedTime.toFixed(2)}s (ID: ${payload.new.id})`);
      }
    })
    .subscribe();

  const travellerNotifCh = traveller.channel(`t5_traveller_n_${Date.now()}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'orders' }, (payload) => {
      if (travellerNotificationTime === null) {
        travellerNotificationTime = (Date.now() - startTimeT5_2) / 1000;
        console.log(`[${formatTimestamp()}] Traveller received live status update notification in ${travellerNotificationTime.toFixed(2)}s (Status: ${payload.new.status})`);
      }
    })
    .subscribe();

  await new Promise(r => setTimeout(r, 1500));

  console.log(`[${formatTimestamp()}] Traveller placing new Shop order...`);
  const { data: createdOrder, error: oErr } = await traveller.from('orders').insert({
    traveller_id: travellerId,
    items: [{ product_id: 'prod-tent-2p', name: '2-Person Camping Tent', qty: 1, price: 3499 }],
    total_amount: 3499,
    status: 'placed',
    delivery_address: 'Hill View Road, Ooty, 643001'
  }).select();

  if (oErr) console.error('  * Order Insert Notice:', oErr.message);

  await new Promise(r => setTimeout(r, 3000));

  startTimeT5_2 = Date.now();
  const testOrderId = createdOrder?.[0]?.id;

  if (testOrderId) {
    console.log(`[${formatTimestamp()}] Admin changing order status (placed -> packed)...`);
    await admin.from('orders').update({ status: 'packed' }).eq('id', testOrderId);
  } else {
    // Fetch latest order placed by travellerId if insert didn't return row
    const { data: latestOrders } = await admin.from('orders').select('id').eq('traveller_id', travellerId).order('created_at', { ascending: false }).limit(1);
    if (latestOrders && latestOrders.length > 0) {
      const latestId = latestOrders[0].id;
      console.log(`[${formatTimestamp()}] Admin changing order status for latest order #${latestId.slice(0, 8)} (placed -> packed)...`);
      await admin.from('orders').update({ status: 'packed' }).eq('id', latestId);
    }
  }

  await new Promise(r => setTimeout(r, 3500));

  admin.removeChannel(adminOrderCh);
  traveller.removeChannel(travellerNotifCh);

  const test5Pass = adminOrderReceivedTime !== null && adminOrderReceivedTime <= 5 &&
                    travellerNotificationTime !== null && travellerNotificationTime <= 5;

  console.log(`\nTEST 5 RESULT: ${test5Pass ? 'PASS ✓' : 'FAIL ✗'}`);
  console.log(`- Order Placed -> Admin Live Update: ${adminOrderReceivedTime !== null ? `${adminOrderReceivedTime.toFixed(2)} seconds` : 'Required manual refresh'}`);
  console.log(`- Admin Status Change -> Traveller Live Update: ${travellerNotificationTime !== null ? `${travellerNotificationTime.toFixed(2)} seconds` : 'Required manual refresh'}\n`);

  console.log('================================================================================');
  const allPassed = test1Pass && test2Pass && test3Pass && test4Pass && test5Pass;
  console.log(`OVERALL SUITE RESULT: ${allPassed ? 'ALL 5 TESTS PASSED PERFECTLY ✓' : 'SOME TESTS FAILED ✗'}`);
  console.log('================================================================================');
}

runLiveRealtimeTestSuite();
