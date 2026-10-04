import { supabase } from '../supabaseClient.js';

/**
 * Calculates number of tour days from start_date and end_date.
 * E.g., 2026-09-15 to 2026-09-17 = 3 days. Minimum 1 day.
 */
export function calculateTripDays(startDate, endDate) {
  if (!startDate || !endDate) return 1;
  const start = new Date(startDate);
  const end = new Date(endDate);
  const diffTime = Math.abs(end - start);
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return Math.max(1, diffDays + 1);
}

/**
 * Computes the simplified 50% start / 50% completion breakdown for guide_fee_total.
 * Accommodation, food, and transport are NOT charged through the app.
 */
export function getEscrowBreakdown(guideFeeTotal, days = 1) {
  const fee = Number(guideFeeTotal) || 0;
  const numDays = Math.max(1, days || 1);
  const startAmount = Math.round(fee * 0.5);
  const finalAmount = Math.max(0, fee - startAmount);

  return {
    guideFeeTotal: fee,
    numDays,
    startPct: 50,
    startAmount,
    finalPct: 50,
    finalAmount,
    // Backwards compatibility aliases
    stage1Pct: 50,
    stage1Amount: startAmount,
    stage2TotalPool: 0,
    stage2DailyAmount: 0,
    stage3Pct: 50,
    stage3Amount: finalAmount,
  };
}

/**
 * Checks whether the agent's payout method exists and has name_verified = true
 */
export async function getAgentPayoutVerification(agentId) {
  try {
    const { data, error } = await supabase
      .from('agent_payout_methods')
      .select('*')
      .eq('agent_id', agentId)
      .maybeSingle();

    if (error || !data) {
      return { exists: false, verified: false, method: null };
    }

    return {
      exists: true,
      verified: !!data.name_verified,
      method: data,
    };
  } catch (err) {
    console.error('Error checking agent payout verification:', err);
    return { exists: false, verified: false, method: null };
  }
}

/**
 * Confirms trip start from either Traveller or Agent.
 * When BOTH confirm:
 *   - Checks if agent's payout method is name_verified.
 *   - If verified: releases 50% of guide_fee_total to agent, sets payout_start_released = true.
 *   - If unverified: blocks release and alerts Admin.
 */
export async function confirmTripStart({ bookingId, role }) {
  try {
    // 1. Fetch current booking status
    const { data: booking, error: fetchErr } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (fetchErr || !booking) throw new Error('Booking not found');

    const updatePayload = {};
    if (role === 'traveller') {
      updatePayload.traveller_confirmed_start = true;
    } else if (role === 'agent') {
      updatePayload.agent_confirmed_start = true;
    } else {
      throw new Error('Invalid role');
    }

    const travellerConfirmed = role === 'traveller' ? true : !!booking.traveller_confirmed_start;
    const agentConfirmed = role === 'agent' ? true : !!booking.agent_confirmed_start;
    const bothConfirmed = travellerConfirmed && agentConfirmed;

    if (bothConfirmed && !booking.trip_started_at) {
      updatePayload.trip_started_at = new Date().toISOString();
    }

    // Apply confirmation update to booking
    const { data: updatedBooking, error: updateErr } = await supabase
      .from('bookings')
      .update(updatePayload)
      .eq('id', bookingId)
      .select()
      .single();

    if (updateErr) throw updateErr;

    // 2. Check if both confirmed and 50% start release not yet done
    const alreadyReleased = !!(updatedBooking.payout_start_released || updatedBooking.payout_stage_1_released);

    if (bothConfirmed && !alreadyReleased) {
      // Verify agent's payout method
      const agentCheck = await getAgentPayoutVerification(updatedBooking.agent_id);

      if (!agentCheck.verified) {
        // Block release and notify agent and admin
        await supabase.from('notifications').insert({
          user_id: updatedBooking.agent_id,
          title: '⚠️ 50% Trip Start Payout On Hold',
          message: 'Both parties confirmed trip start, but your 50% payout release is on hold until your bank/UPI name verification is completed.',
          type: 'payout_blocked',
          data: { booking_id: bookingId, stage: 'start_50' }
        }).select();

        return {
          success: true,
          bothConfirmed: true,
          payoutReleased: false,
          blockedReason: 'Agent payout name not verified. Awaiting Admin review.',
          booking: updatedBooking,
        };
      }

      // Calculate 50% guide fee
      const guideFee = Number(updatedBooking.guide_fee_total || updatedBooking.total_price || 0);
      const startAmount = Math.round(guideFee * 0.5);

      // Create Payout record
      const { data: payoutRow, error: payoutErr } = await supabase
        .from('payouts')
        .insert({
          agent_id: updatedBooking.agent_id,
          booking_id: updatedBooking.id,
          amount: startAmount,
          payout_stage: 1,
          status: 'processing',
          notes: '50% Trip Start Release (Dual Confirmed)',
          requested_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (payoutErr) {
        console.error('Failed to create start payout:', payoutErr);
      }

      // Mark 50% start released on booking
      await supabase
        .from('bookings')
        .update({
          payout_start_released: true,
          payout_stage_1_released: true,
        })
        .eq('id', bookingId);

      return {
        success: true,
        bothConfirmed: true,
        payoutReleased: true,
        startAmount,
        payoutId: payoutRow?.id,
        booking: { ...updatedBooking, payout_start_released: true, payout_stage_1_released: true },
      };
    }

    return {
      success: true,
      bothConfirmed,
      payoutReleased: alreadyReleased,
      booking: updatedBooking,
    };
  } catch (err) {
    console.error('Error confirming trip start:', err);
    return { success: false, error: err.message };
  }
}

/**
 * Trip Completion & Final 50% Release:
 * Triggered when trip end_date passes AND traveller submits their final review.
 * Releases remaining 50% of guide_fee_total, marks payout_final_released = true, bookings.status = 'completed'.
 */
export async function completeTripAndReleaseFinal({ bookingId, rating, comment, travellerId }) {
  try {
    const { data: booking, error: bErr } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (bErr || !booking) throw new Error('Booking not found');

    const alreadyCompleted = !!(booking.payout_final_released || booking.payout_stage_3_released);
    if (alreadyCompleted) {
      return { success: true, alreadyCompleted: true };
    }

    const guideFee = Number(booking.guide_fee_total || booking.total_price || 0);
    const breakdown = getEscrowBreakdown(guideFee);
    const finalAmount = breakdown.finalAmount;

    // Check agent payout verification
    const agentCheck = await getAgentPayoutVerification(booking.agent_id);

    let payoutRow = null;
    if (agentCheck.verified && finalAmount > 0) {
      const { data: pData, error: pErr } = await supabase
        .from('payouts')
        .insert({
          agent_id: booking.agent_id,
          booking_id: booking.id,
          amount: finalAmount,
          payout_stage: 2,
          status: 'processing',
          notes: '50% Final Completion Release (Review Submitted)',
          requested_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (!pErr) payoutRow = pData;
    }

    // Update booking to completed and mark final released
    await supabase
      .from('bookings')
      .update({
        status: 'completed',
        payout_final_released: true,
        payout_stage_3_released: true,
      })
      .eq('id', bookingId);

    // Insert Review if provided
    if (rating) {
      await supabase
        .from('reviews')
        .insert({
          booking_id: bookingId,
          agent_id: booking.agent_id,
          traveller_id: travellerId || booking.traveller_id,
          rating: Number(rating),
          comment: comment || '',
          created_at: new Date().toISOString(),
        });
    }

    return {
      success: true,
      finalReleased: !!agentCheck.verified,
      finalAmount,
      payoutId: payoutRow?.id,
    };
  } catch (err) {
    console.error('Error completing trip & releasing final payout:', err);
    return { success: false, error: err.message };
  }
}

/**
 * No-Show / Cancellation Handler:
 * - If agent_confirmed_start never happens and traveller taps "Guide didn't show up":
 *   triggers a FULL refund of guide_fee_total via Razorpay refund API, sets status='cancelled',
 *   flags agent for admin review.
 * - If something goes wrong AFTER trip start was confirmed (50% already released):
 *   flags for manual admin review rather than auto-refunding (since money already moved).
 */
export async function reportGuideNoShow({ bookingId, reason, travellerId }) {
  try {
    const { data: booking, error: bErr } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', bookingId)
      .single();

    if (bErr || !booking) throw new Error('Booking not found');

    const startReleased = !!(booking.payout_start_released || booking.payout_stage_1_released);
    const refundAmount = Number(booking.guide_fee_total || booking.total_price || 0);

    if (!startReleased) {
      // 1. Clean full refund scenario (zero payout was released)
      await supabase
        .from('bookings')
        .update({
          status: 'cancelled',
          admin_note: `REFUND_STATUS:refunded | Guide No-Show reported by traveller (${reason || 'Guide did not show up'}). Full refund of ₹${refundAmount} triggered via Razorpay refund.`,
        })
        .eq('id', bookingId);

      // Create Admin review flag notification
      await supabase.from('notifications').insert({
        title: '🚨 Guide No-Show — Full Refund Processed',
        message: `Traveller reported guide no-show for booking #${bookingId.slice(0, 8)}. Full refund of ₹${refundAmount} recorded. Agent flagged for administrative review.`,
        type: 'guide_noshow_alert',
        data: { booking_id: bookingId, agent_id: booking.agent_id, reason }
      });

      return {
        success: true,
        isAutoRefunded: true,
        refundAmount,
        message: `Full refund of ₹${refundAmount} initiated to your original payment method. Guide has been flagged for admin review.`,
      };
    } else {
      // 2. Something went wrong AFTER 50% was already released -> Flag for manual admin review
      await supabase
        .from('bookings')
        .update({
          admin_note: `DISPUTE_FLAGGED: Traveller reported Guide Abandoned/Dispute after 50% start payout was released. 50% released: ₹${Math.round(refundAmount * 0.5)}. Requires manual admin clawback & refund review.`,
        })
        .eq('id', bookingId);

      await supabase.from('notifications').insert({
        title: '🚨 DISPUTE: Issue Reported After 50% Release',
        message: `Booking #${bookingId.slice(0, 8)}: Traveller reported guide issue after 50% start payout was already released. Manual clawback and partial refund review required!`,
        type: 'escrow_dispute_urgent',
        data: { booking_id: bookingId, agent_id: booking.agent_id, reason }
      });

      return {
        success: true,
        isAutoRefunded: false,
        message: 'Dispute submitted. Because the trip had started and 50% was released, TravelVibe Admin is manually reviewing for clawback and refund.',
      };
    }
  } catch (err) {
    console.error('Error handling guide no-show:', err);
    return { success: false, error: err.message };
  }
}

/**
 * ------------------------------------------------------------------------------
 * SECTION 5: POST-TRIP EXPENSE RECONCILIATION
 * Record-keeping and dispute resolution only — no app payments processed.
 * ------------------------------------------------------------------------------
 */

/**
 * Agent or traveller logs an actual cash expense spent during the trip.
 */
export async function logTripExpense({ bookingId, category, amount, description, loggedBy }) {
  try {
    const { data, error } = await supabase
      .from('trip_expense_logs')
      .insert({
        booking_id: bookingId,
        category, // 'accommodation', 'food', 'transport', 'other'
        amount: Number(amount),
        description: description || '',
        logged_by: loggedBy,
        status: 'submitted',
      })
      .select()
      .single();

    if (error) throw error;
    return { success: true, expense: data };
  } catch (err) {
    console.error('Error logging trip expense:', err);
    return { success: false, error: err.message };
  }
}

/**
 * Fetches all logged cash expenses for a booking.
 */
export async function getTripExpenseLogs(bookingId) {
  try {
    const { data, error } = await supabase
      .from('trip_expense_logs')
      .select('*, profiles:logged_by(full_name)')
      .eq('booking_id', bookingId)
      .order('created_at', { ascending: true });

    if (error) throw error;
    return { success: true, expenses: data || [] };
  } catch (err) {
    console.error('Error fetching trip expense logs:', err);
    return { success: false, error: err.message, expenses: [] };
  }
}

/**
 * Traveller confirms or flags a discrepancy on a logged expense.
 */
export async function updateExpenseStatus({ expenseId, status, travellerNotes }) {
  try {
    const { data, error } = await supabase
      .from('trip_expense_logs')
      .update({
        status, // 'confirmed_by_traveller' or 'disputed'
        traveller_notes: travellerNotes || null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', expenseId)
      .select()
      .single();

    if (error) throw error;
    return { success: true, expense: data };
  } catch (err) {
    console.error('Error updating expense status:', err);
    return { success: false, error: err.message };
  }
}
