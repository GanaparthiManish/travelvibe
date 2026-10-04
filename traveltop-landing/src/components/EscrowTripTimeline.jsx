import React, { useState, useEffect } from 'react';
import {
  calculateTripDays,
  getEscrowBreakdown,
  confirmTripStart,
  completeTripAndReleaseFinal,
  reportGuideNoShow,
  logTripExpense,
  getTripExpenseLogs,
  updateExpenseStatus,
} from '../services/escrowService';
import { supabase } from '../supabaseClient';
import {
  CheckCircle2,
  AlertCircle,
  Clock,
  ShieldAlert,
  ChevronDown,
  ChevronUp,
  Star,
  Receipt,
  Plus,
  ShieldCheck,
} from 'lucide-react';

export default function EscrowTripTimeline({ booking, role, onUpdated, onOpenSOS }) {
  const [expanded, setExpanded] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [finalRating, setFinalRating] = useState(5);
  const [finalComment, setFinalComment] = useState('');

  // Post-trip Expense Reconciliation State (Section 5)
  const [expenseLogs, setExpenseLogs] = useState([]);
  const [showExpenseForm, setShowExpenseForm] = useState(false);
  const [expCategory, setExpCategory] = useState('food');
  const [expAmount, setExpAmount] = useState('');
  const [expDesc, setExpDesc] = useState('');
  const [savingExpense, setSavingExpense] = useState(false);

  const numDays = calculateTripDays(booking.start_date, booking.end_date);
  const guideFee = Number(booking.guide_fee_total || booking.total_price || 0);
  const breakdown = getEscrowBreakdown(guideFee, numDays);
  const estimatedCash = Number(booking.estimated_daily_expenses || 1500);

  const travellerStarted = !!booking.traveller_confirmed_start;
  const agentStarted = !!booking.agent_confirmed_start;
  const bothStarted = travellerStarted && agentStarted;
  const startPayoutReleased = !!(booking.payout_start_released || booking.payout_stage_1_released);
  const finalPayoutReleased = !!(booking.payout_final_released || booking.payout_stage_3_released);
  const isCompleted = booking.status === 'completed' || finalPayoutReleased;

  // Load expense logs
  const fetchExpenses = async () => {
    const res = await getTripExpenseLogs(booking.id);
    if (res.success) {
      setExpenseLogs(res.expenses);
    }
  };

  useEffect(() => {
    fetchExpenses();
    const channel = supabase
      .channel(`expense_logs_${booking.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trip_expense_logs', filter: `booking_id=eq.${booking.id}` }, fetchExpenses)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [booking.id]);

  const handleConfirmStart = async () => {
    setActionLoading(true);
    const res = await confirmTripStart({ bookingId: booking.id, role });
    setActionLoading(false);
    if (!res.success) {
      alert('Error confirming start: ' + (res.error || 'Unknown error'));
    } else {
      if (res.blockedReason) {
        alert(res.blockedReason);
      }
      if (onUpdated) onUpdated();
    }
  };

  const handleFinalReviewSubmit = async (e) => {
    e.preventDefault();
    setActionLoading(true);
    const res = await completeTripAndReleaseFinal({
      bookingId: booking.id,
      rating: finalRating,
      comment: finalComment,
      travellerId: booking.traveller_id,
    });
    setActionLoading(false);
    setShowReviewModal(false);

    if (!res.success) {
      alert('Error completing trip: ' + res.error);
    } else {
      if (onUpdated) onUpdated();
    }
  };

  const handleNoShow = async () => {
    const promptMsg = startPayoutReleased
      ? '50% of the guide fee was already released upon trip start. Submitting an issue will flag this booking for immediate TravelVibe Admin manual clawback review. Proceed?'
      : 'Has the guide failed to show up? This will cancel the trip and trigger an immediate FULL refund of ₹' + guideFee + ' to your original payment method. Continue?';

    if (!window.confirm(promptMsg)) return;

    setActionLoading(true);
    const res = await reportGuideNoShow({
      bookingId: booking.id,
      reason: 'Guide did not show up at scheduled meeting point',
      travellerId: booking.traveller_id,
    });
    setActionLoading(false);

    alert(res.message || 'Guide report submitted.');
    if (onUpdated) onUpdated();
  };

  const handleAddExpense = async (e) => {
    e.preventDefault();
    if (!expAmount || Number(expAmount) <= 0) return;

    setSavingExpense(true);
    const res = await logTripExpense({
      bookingId: booking.id,
      category: expCategory,
      amount: expAmount,
      description: expDesc,
      loggedBy: role === 'agent' ? booking.agent_id : booking.traveller_id,
    });
    setSavingExpense(false);

    if (res.success) {
      setExpAmount('');
      setExpDesc('');
      setShowExpenseForm(false);
      fetchExpenses();
    } else {
      alert('Failed to log expense: ' + res.error);
    }
  };

  const handleUpdateExpense = async (expenseId, status) => {
    const notes = status === 'disputed' ? prompt('Optional reason for discrepancy:') : null;
    const res = await updateExpenseStatus({
      expenseId,
      status,
      travellerNotes: notes,
    });
    if (res.success) {
      fetchExpenses();
    }
  };

  return (
    <div className="bg-white rounded-3xl border border-gray-200 overflow-hidden shadow-xs">
      {/* HEADER SUMMARY */}
      <div className="p-5 sm:p-6 bg-gradient-to-r from-[#1B1924] to-[#2B273F] text-white flex items-center justify-between">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <span className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider bg-orange-500/20 text-[#FFA767] border border-orange-500/30">
              50% / 50% Staged Release
            </span>
            <span className="text-xs text-gray-300 font-semibold">• Guide Service Fee Only</span>
          </div>
          <h3 className="text-base sm:text-lg font-black tracking-tight">
            Protected Escrow: ₹{guideFee.toLocaleString()}
          </h3>
        </div>

        <div className="flex items-center gap-2">
          {onOpenSOS && (
            <button
              onClick={onOpenSOS}
              className="px-3 py-1.5 bg-rose-600 hover:bg-rose-700 text-white font-black text-xs rounded-xl flex items-center gap-1 shadow-md animate-pulse"
            >
              <ShieldAlert className="w-3.5 h-3.5" /> SOS
            </button>
          )}

          <button
            onClick={() => setExpanded(!expanded)}
            className="p-2 text-gray-400 hover:text-white rounded-xl bg-white/5 transition-colors"
          >
            {expanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {expanded && (
        <div className="p-5 sm:p-6 space-y-6">
          {/* INFORMATIONAL CASH BANNER (SECTION 2) */}
          <div className="p-4 bg-amber-50/90 rounded-2xl border border-amber-200 flex items-start gap-3">
            <span className="text-xl shrink-0">💵</span>
            <div className="space-y-0.5 text-xs">
              <p className="font-extrabold text-amber-950">
                Estimated cash to carry per day: ₹{estimatedCash} (accommodation, food, local transport)
              </p>
              <p className="text-amber-900 font-medium">
                Total trip cash estimate: <strong>₹{(estimatedCash * numDays).toLocaleString()}</strong>.
                You pay this directly in cash during the trip — it is <strong>NOT charged through the app</strong> and requires no live signal.
              </p>
            </div>
          </div>

          {/* TWO-STAGE ESCROW CARDS */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* STAGE 1: 50% ON TRIP START */}
            <div className={`p-4 rounded-2xl border transition-all ${
              startPayoutReleased
                ? 'bg-emerald-50/50 border-emerald-200'
                : bothStarted
                ? 'bg-amber-50/50 border-amber-200'
                : 'bg-gray-50 border-gray-200'
            }`}>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-extrabold uppercase tracking-wider text-gray-500">
                  Stage 1 (50% on Start)
                </span>
                <span className="text-sm font-black text-[#E8741F]">
                  ₹{breakdown.startAmount.toLocaleString()}
                </span>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-gray-600">Traveller Confirmed:</span>
                  <span className={`font-bold ${travellerStarted ? 'text-emerald-600' : 'text-gray-400'}`}>
                    {travellerStarted ? '✓ Confirmed' : 'Pending'}
                  </span>
                </div>
                <div className="flex items-center justify-between text-xs">
                  <span className="text-gray-600">Guide Confirmed:</span>
                  <span className={`font-bold ${agentStarted ? 'text-emerald-600' : 'text-gray-400'}`}>
                    {agentStarted ? '✓ Confirmed' : 'Pending'}
                  </span>
                </div>

                <div className="pt-2 border-t border-gray-200/60 flex items-center justify-between">
                  <span className="text-xs font-semibold text-gray-500">50% Payout Status:</span>
                  <span className={`text-xs font-extrabold px-2 py-0.5 rounded-full ${
                    startPayoutReleased
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-gray-200 text-gray-700'
                  }`}>
                    {startPayoutReleased ? 'Released to Guide' : 'Held in Escrow'}
                  </span>
                </div>

                {/* Confirm start actions */}
                {!startPayoutReleased && booking.status !== 'cancelled' && (
                  <div className="pt-3 space-y-2">
                    {((role === 'traveller' && !travellerStarted) || (role === 'agent' && !agentStarted)) && (
                      <button
                        onClick={handleConfirmStart}
                        disabled={actionLoading}
                        className="w-full py-2 bg-[#E8741F] text-white font-extrabold text-xs rounded-xl shadow-xs hover:bg-[#D66311] transition-all"
                      >
                        {actionLoading ? 'Confirming...' : 'Confirm Trip Started'}
                      </button>
                    )}

                    {role === 'traveller' && (
                      <button
                        onClick={handleNoShow}
                        disabled={actionLoading}
                        className="w-full py-1.5 text-[11px] font-bold text-rose-600 hover:text-rose-700 hover:bg-rose-50 rounded-lg transition-colors"
                      >
                        Guide didn't show up? Request Full Refund
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>

            {/* STAGE 2: 50% ON COMPLETION & REVIEW */}
            <div className={`p-4 rounded-2xl border transition-all ${
              finalPayoutReleased
                ? 'bg-emerald-50/50 border-emerald-200'
                : 'bg-gray-50 border-gray-200'
            }`}>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-extrabold uppercase tracking-wider text-gray-500">
                  Stage 2 (50% on Completion)
                </span>
                <span className="text-sm font-black text-[#E8741F]">
                  ₹{breakdown.finalAmount.toLocaleString()}
                </span>
              </div>

              <div className="space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="text-gray-600">Trip Finished & Reviewed:</span>
                  <span className={`font-bold ${finalPayoutReleased ? 'text-emerald-600' : 'text-gray-400'}`}>
                    {finalPayoutReleased ? '✓ Completed' : 'Awaiting End Date & Review'}
                  </span>
                </div>

                <div className="pt-2 border-t border-gray-200/60 flex items-center justify-between">
                  <span className="text-xs font-semibold text-gray-500">Final Payout Status:</span>
                  <span className={`text-xs font-extrabold px-2 py-0.5 rounded-full ${
                    finalPayoutReleased
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-gray-200 text-gray-700'
                  }`}>
                    {finalPayoutReleased ? 'Released to Guide' : 'Held in Escrow'}
                  </span>
                </div>

                {startPayoutReleased && !finalPayoutReleased && role === 'traveller' && (
                  <div className="pt-3">
                    <button
                      onClick={() => setShowReviewModal(true)}
                      className="w-full py-2 bg-emerald-600 text-white font-extrabold text-xs rounded-xl shadow-xs hover:bg-emerald-700 transition-all"
                    >
                      Complete Trip & Submit Review
                    </button>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* POST-TRIP EXPENSE RECONCILIATION SECTION (SECTION 5) */}
          <div className="pt-4 border-t border-gray-200 space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-xs font-extrabold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
                  <Receipt className="w-4 h-4 text-[#E8741F]" />
                  Post-Trip Cash Expense Reconciliation (Optional)
                </h4>
                <p className="text-[11px] text-gray-500 font-medium">
                  Record-keeping & dispute paper trail once signal returns. No payment is processed here.
                </p>
              </div>

              <button
                onClick={() => setShowExpenseForm(!showExpenseForm)}
                className="px-3 py-1 bg-gray-100 hover:bg-gray-200 text-gray-700 font-bold text-xs rounded-lg flex items-center gap-1 transition-colors"
              >
                <Plus className="w-3.5 h-3.5" /> Log Expense
              </button>
            </div>

            {/* EXPENSE LOG FORM */}
            {showExpenseForm && (
              <form onSubmit={handleAddExpense} className="p-4 bg-gray-50 rounded-2xl border border-gray-200 space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div>
                    <label className="block text-[10px] font-bold text-gray-600 uppercase mb-1">Category</label>
                    <select
                      value={expCategory}
                      onChange={(e) => setExpCategory(e.target.value)}
                      className="w-full px-3 py-2 bg-white border border-gray-200 rounded-xl text-xs font-semibold"
                    >
                      <option value="accommodation">🏨 Accommodation</option>
                      <option value="food">🍽️ Food & Meals</option>
                      <option value="transport">🚕 Local Transport</option>
                      <option value="other">📦 Other / Entry Tickets</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-[10px] font-bold text-gray-600 uppercase mb-1">Amount (₹)</label>
                    <input
                      type="number"
                      required
                      min="1"
                      value={expAmount}
                      onChange={(e) => setExpAmount(e.target.value)}
                      placeholder="e.g. 1200"
                      className="w-full px-3 py-2 bg-white border border-gray-200 rounded-xl text-xs font-semibold"
                    />
                  </div>

                  <div>
                    <label className="block text-[10px] font-bold text-gray-600 uppercase mb-1">Description / Notes</label>
                    <input
                      type="text"
                      value={expDesc}
                      onChange={(e) => setExpDesc(e.target.value)}
                      placeholder="e.g. Homestay Day 1, Jeep to Peak"
                      className="w-full px-3 py-2 bg-white border border-gray-200 rounded-xl text-xs font-semibold"
                    />
                  </div>
                </div>

                <div className="flex justify-end gap-2">
                  <button
                    type="button"
                    onClick={() => setShowExpenseForm(false)}
                    className="px-3 py-1.5 text-xs text-gray-500 font-bold hover:bg-gray-100 rounded-lg"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={savingExpense}
                    className="px-4 py-1.5 bg-[#E8741F] text-white text-xs font-bold rounded-lg shadow-xs hover:bg-[#D66311]"
                  >
                    {savingExpense ? 'Saving...' : 'Save Record'}
                  </button>
                </div>
              </form>
            )}

            {/* EXPENSE LOGS LIST */}
            {expenseLogs.length > 0 ? (
              <div className="divide-y divide-gray-100 border border-gray-100 rounded-2xl overflow-hidden">
                {expenseLogs.map((log) => (
                  <div key={log.id} className="p-3 bg-white flex items-center justify-between gap-3 text-xs">
                    <div>
                      <span className="font-extrabold capitalize text-gray-900 mr-2">
                        {log.category === 'accommodation' ? '🏨 Stay' : log.category === 'food' ? '🍽️ Food' : log.category === 'transport' ? '🚕 Transport' : '📦 Other'}
                      </span>
                      <span className="text-gray-600">{log.description || 'No description'}</span>
                      {log.traveller_notes && (
                        <p className="text-[10px] text-amber-700 font-semibold mt-0.5">
                          Note: {log.traveller_notes}
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-3 shrink-0">
                      <span className="font-black text-gray-900">₹{Number(log.amount).toLocaleString()}</span>
                      
                      {role === 'traveller' && log.status === 'submitted' ? (
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => handleUpdateExpense(log.id, 'confirmed_by_traveller')}
                            className="px-2 py-0.5 bg-emerald-50 text-emerald-700 border border-emerald-200 font-bold rounded-md hover:bg-emerald-100"
                          >
                            ✓ Confirm
                          </button>
                          <button
                            onClick={() => handleUpdateExpense(log.id, 'disputed')}
                            className="px-2 py-0.5 bg-rose-50 text-rose-700 border border-rose-200 font-bold rounded-md hover:bg-rose-100"
                          >
                            Flag Discrepancy
                          </button>
                        </div>
                      ) : (
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-extrabold ${
                          log.status === 'confirmed_by_traveller'
                            ? 'bg-emerald-100 text-emerald-800'
                            : log.status === 'disputed'
                            ? 'bg-rose-100 text-rose-800'
                            : 'bg-gray-100 text-gray-600'
                        }`}>
                          {log.status === 'confirmed_by_traveller' ? '✓ Confirmed' : log.status === 'disputed' ? '⚠️ Discrepancy' : 'Submitted'}
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-gray-400 italic">No cash expenses logged for this trip yet.</p>
            )}
          </div>
        </div>
      )}

      {/* FINAL REVIEW MODAL */}
      {showReviewModal && (
        <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 space-y-4 shadow-xl">
            <h3 className="text-lg font-black text-gray-900">Complete Trip & Release Final 50%</h3>
            <p className="text-xs text-gray-500 font-medium">
              Submitting this review confirms trip completion and releases the final 50% of the guide fee (₹{breakdown.finalAmount.toLocaleString()}) to your guide.
            </p>

            <form onSubmit={handleFinalReviewSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Guide Rating</label>
                <div className="flex gap-2">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      key={star}
                      type="button"
                      onClick={() => setFinalRating(star)}
                      className="p-2"
                    >
                      <Star
                        className={`w-6 h-6 ${
                          star <= finalRating ? 'text-amber-400 fill-amber-400' : 'text-gray-300'
                        }`}
                      />
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Trip Review & Feedback</label>
                <textarea
                  rows={3}
                  value={finalComment}
                  onChange={(e) => setFinalComment(e.target.value)}
                  placeholder="How was your guide? What were the trip highlights?"
                  className="w-full px-3 py-2 border border-gray-200 rounded-xl text-xs focus:outline-none focus:border-[#E8741F]"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowReviewModal(false)}
                  className="px-4 py-2 text-xs font-bold text-gray-600 hover:bg-gray-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={actionLoading}
                  className="px-5 py-2 bg-emerald-600 text-white text-xs font-extrabold rounded-xl hover:bg-emerald-700 shadow-md"
                >
                  {actionLoading ? 'Releasing Payout...' : 'Submit & Release 50%'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
