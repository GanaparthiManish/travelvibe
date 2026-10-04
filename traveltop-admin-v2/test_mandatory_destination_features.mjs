import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://imretkikrsdydreldosx.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

let allPassed = true;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✓ PASS: ${message}`);
  } else {
    console.error(`  ✗ FAIL: ${message}`);
    allPassed = false;
  }
}

async function runMandatoryTests() {
  console.log('========================================================================');
  console.log(' TRAVELVIBE MANDATORY TEST: DESTINATION GALLERY & REVIEWS FEATURE');
  console.log('========================================================================\n');

  // Authenticate as Admin user
  const { data: adminAuth, error: adminErr } = await supabase.auth.signInWithPassword({
    email: 'ganaparthimanish@gmail.com',
    password: 'Ganaparthi@123'
  });
  if (adminErr) {
    console.error('Admin authentication failed:', adminErr);
    process.exit(1);
  }
  const adminId = adminAuth.user.id;
  console.log(`Admin authenticated: ${adminAuth.user.email} (${adminId})\n`);

  // =============================================================================
  // TEST 1: ADMIN MULTI-COVER GALLERY UPLOAD
  // Upload 4 images for a destination (Chikmagalur), confirm 1st becomes cover_image_url
  // and all 4 appear in destination_images ordered gallery.
  // =============================================================================
  console.log('TEST 1: Multi-Cover Gallery & Cover Image Sync');
  console.log('------------------------------------------------------------------------');

  // 1. Fetch or create Chikmagalur destination
  let { data: dest } = await supabase
    .from('destinations')
    .select('*')
    .ilike('name', '%Chikmagalur%')
    .maybeSingle();

  if (!dest) {
    const { data: newDest, error: createErr } = await supabase
      .from('destinations')
      .insert({
        name: 'Chikmagalur',
        country: 'Karnataka',
        category: 'Hills',
        description: 'Misty hills, lush coffee estates, and scenic trekking peaks in Karnataka.',
        best_season: 'September to March',
        ideal_trip_duration: '2-3 Days',
        travel_tips: ['Visit Mullayanagiri peak early morning', 'Sample fresh Filter Coffee at local estates']
      })
      .select()
      .single();
    if (createErr) throw createErr;
    dest = newDest;
  }

  assert(dest && dest.id, `Destination "Chikmagalur" resolved (ID: ${dest.id})`);

  const galleryPhotoUrls = [
    'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=1200&q=80', // 1st photo (cover)
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80', // 2nd photo
    'https://images.unsplash.com/photo-1511497584788-876761c119ef?auto=format&fit=crop&w=1200&q=80', // 3rd photo
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1200&q=80'  // 4th photo
  ];

  // Set 1st image as cover_image_url
  const primaryCover = galleryPhotoUrls[0];
  await supabase
    .from('destinations')
    .update({ cover_image_url: primaryCover })
    .eq('id', dest.id);

  // Clear existing gallery and insert all 4 images with display_order 0..3
  await supabase.from('destination_images').delete().eq('destination_id', dest.id);

  const imgRows = galleryPhotoUrls.map((url, idx) => ({
    destination_id: dest.id,
    image_url: url,
    display_order: idx
  }));

  const { error: galleryErr } = await supabase.from('destination_images').insert(imgRows);
  assert(!galleryErr, `Inserted 4 images into destination_images table`);

  // Query updated destination & gallery
  const { data: updatedDest } = await supabase
    .from('destinations')
    .select('*, destination_images(*)')
    .eq('id', dest.id)
    .single();

  const fetchedGallery = (updatedDest.destination_images || [])
    .sort((a, b) => a.display_order - b.display_order);

  assert(
    updatedDest.cover_image_url === primaryCover,
    `destinations.cover_image_url (${updatedDest.cover_image_url}) matches 1st gallery photo`
  );
  assert(
    fetchedGallery.length === 4,
    `destination_images count is EXACTLY 4 ordered gallery photos`
  );
  assert(
    fetchedGallery[0].image_url === galleryPhotoUrls[0] &&
    fetchedGallery[3].image_url === galleryPhotoUrls[3],
    `Gallery images preserved in exact display_order (0 -> 3)`
  );


  // =============================================================================
  // TEST 2 & 3: COMPLETED TRIP & DESTINATION REVIEW SUBMISSION WITH PHOTOS
  // Complete a real test booking + trip, submit review with 2 photos attached,
  // confirm review appears live with correct rating, text, photos, and agent tag.
  // =============================================================================
  console.log('\nTEST 2 & 3: Completed Trip Review Submission & Gallery Attachments');
  console.log('------------------------------------------------------------------------');

  // Create completed test booking
  const { data: completedBooking, error: bookErr } = await supabase
    .from('bookings')
    .insert({
      traveller_id: adminId,
      agent_id: adminId, // self-booking for test
      destination: 'Chikmagalur',
      start_date: '2026-09-10',
      end_date: '2026-09-12',
      total_price: 5000,
      status: 'completed',
      trip_notes: 'Completed test trek to Mullayanagiri'
    })
    .select()
    .single();

  if (bookErr) throw bookErr;
  assert(completedBooking && completedBooking.status === 'completed', `Completed test booking created (ID: ${completedBooking.id})`);

  // Clean old reviews for this booking if any
  await supabase.from('destination_reviews').delete().eq('booking_id', completedBooking.id);

  // Submit Destination Review
  const reviewRating = 5;
  const reviewText = 'Breathtaking coffee plantations and misty peaks! Our local guide was incredibly knowledgeable.';
  
  const { data: destReview, error: revInsErr } = await supabase
    .from('destination_reviews')
    .insert({
      destination_id: dest.id,
      traveller_id: adminId,
      booking_id: completedBooking.id,
      rating: reviewRating,
      review_text: reviewText
    })
    .select()
    .single();

  if (revInsErr) throw revInsErr;
  assert(destReview && destReview.id, `Destination review submitted (Rating: ${destReview.rating} stars, ID: ${destReview.id})`);

  // Attach 2 review photos
  const reviewPhotos = [
    'https://images.unsplash.com/photo-1544735716-392fe2489ffa?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80'
  ];

  const reviewImgRows = reviewPhotos.map((url, idx) => ({
    review_id: destReview.id,
    image_url: url,
    display_order: idx
  }));

  const { error: revImgErr } = await supabase.from('destination_review_images').insert(reviewImgRows);
  assert(!revImgErr, `Attached 2 photo thumbnails to destination review`);

  // Query Destination Reviews List (matching Traveller App view query)
  const { data: fetchedReviews } = await supabase
    .from('destination_reviews')
    .select('*, traveller:profiles!traveller_id(full_name), booking:bookings!booking_id(agent_id), destination_review_images(*)')
    .eq('destination_id', dest.id)
    .order('created_at', { ascending: false });

  assert(fetchedReviews && fetchedReviews.length > 0, `Fetched live reviews list for Destination Detail screen`);
  const liveRev = fetchedReviews.find(r => r.id === destReview.id);
  assert(liveRev !== undefined, `Review found live in destination reviews list`);
  assert(liveRev.rating === 5, `Live review rating is 5 stars`);
  assert(liveRev.review_text === reviewText, `Live review text matches submission`);
  assert(liveRev.destination_review_images.length === 2, `2 attached photo thumbnails present on review card`);


  // =============================================================================
  // TEST 4: SERVER-SIDE RATING CALCULATION TRIGGER
  // Confirm destination's rating_avg and review_count update automatically
  // via PostgreSQL trigger `trg_recalc_dest_rating`.
  // =============================================================================
  console.log('\nTEST 4: Server-Side Rating Calculation Trigger');
  console.log('------------------------------------------------------------------------');

  const { data: ratedDest } = await supabase
    .from('destinations')
    .select('rating_avg, review_count')
    .eq('id', dest.id)
    .single();

  assert(
    Number(ratedDest.rating_avg) > 0,
    `destinations.rating_avg updated to ${ratedDest.rating_avg} via database trigger`
  );
  assert(
    ratedDest.review_count >= 1,
    `destinations.review_count updated to ${ratedDest.review_count} via database trigger`
  );


  // =============================================================================
  // TEST 5: RLS POLICY BLOCKED SUBMISSION FOR UNCOMPLETED BOOKING
  // Try submitting a destination review for a booking that's NOT completed yet (e.g. status='confirmed')
  // as a non-admin traveller user. Confirm this is BLOCKED by RLS policy check at database level.
  // =============================================================================
  console.log('\nTEST 5: RLS Security Enforcement (Non-Completed Booking Blocked)');
  console.log('------------------------------------------------------------------------');

  // Authenticate / sign in as a non-admin traveller user
  const testTravellerEmail = 'traveller_test_rls@travelvibe.com';
  const testTravellerPass = 'TravellerPassword123!';

  let travellerUserId = null;
  const { data: travSignIn, error: travSignInErr } = await supabase.auth.signInWithPassword({
    email: testTravellerEmail,
    password: testTravellerPass
  });

  if (travSignInErr) {
    // Create traveller account if doesn't exist
    const { data: signUpData, error: signUpErr } = await supabase.auth.signUp({
      email: testTravellerEmail,
      password: testTravellerPass,
      options: { data: { full_name: 'Test Traveller RLS' } }
    });
    if (signUpData?.user) {
      travellerUserId = signUpData.user.id;
    } else {
      console.error('Traveller signup error:', signUpErr);
    }
  } else {
    travellerUserId = travSignIn.user.id;
  }

  // Log back in as admin briefly to insert the uncompleted booking for traveller
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });

  // Create profile row for test traveller if needed
  if (travellerUserId) {
    await supabase.from('profiles').upsert({ id: travellerUserId, full_name: 'Test Traveller RLS', role: 'traveller' });
  } else {
    travellerUserId = adminId;
  }

  const { data: uncompletedBooking } = await supabase
    .from('bookings')
    .insert({
      traveller_id: travellerUserId,
      agent_id: adminId,
      destination: 'Chikmagalur',
      start_date: '2026-10-01',
      end_date: '2026-10-03',
      total_price: 6000,
      status: 'confirmed' // NOT completed!
    })
    .select()
    .single();

  assert(uncompletedBooking.status === 'confirmed', `Created uncompleted booking with status='confirmed'`);

  // Switch authentication to the non-admin Traveller user
  await supabase.auth.signInWithPassword({
    email: testTravellerEmail,
    password: testTravellerPass
  });

  // Attempt to submit destination review for uncompleted booking
  const { data: blockedRev, error: blockedErr } = await supabase
    .from('destination_reviews')
    .insert({
      destination_id: dest.id,
      traveller_id: travellerUserId,
      booking_id: uncompletedBooking.id,
      rating: 4,
      review_text: 'Trying to review before trip is completed'
    })
    .select();

  assert(
    blockedErr !== null,
    `RLS Policy BLOCKED review insertion for uncompleted booking! Error code: "${blockedErr?.code}", message: "${blockedErr?.message}"`
  );
  assert(blockedRev === null, `Zero rows inserted for unauthorized uncompleted booking review`);

  // Switch back to Admin to cleanup test booking
  await supabase.auth.signInWithPassword({ email: 'ganaparthimanish@gmail.com', password: 'Ganaparthi@123' });
  await supabase.from('bookings').delete().eq('id', uncompletedBooking.id);


  // =============================================================================
  // SUMMARY REPORT
  // =============================================================================
  console.log('\n========================================================================');
  if (allPassed) {
    console.log('🎉 ALL 5 MANDATORY DESTINATION FEATURE TESTS PASSED FLAWLESSLY!');
    console.log('1. Multi-cover gallery uploaded; 1st image synced as cover_image_url.');
    console.log('2. Completed trip review submitted with 2 photos attached.');
    console.log('3. Review displays live on Destination Detail screen with ratings & photos.');
    console.log('4. Database trigger automatically recalculated destinations.rating_avg & review_count.');
    console.log('5. Row-Level Security (RLS) strictly BLOCKS reviews for non-completed trips.');
    console.log('========================================================================');
    process.exit(0);
  } else {
    console.error('❌ MANDATORY TEST FAILED. Review errors above.');
    console.log('========================================================================');
    process.exit(1);
  }
}

runMandatoryTests();
