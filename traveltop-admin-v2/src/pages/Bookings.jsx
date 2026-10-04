import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import StatusBadge from '../components/StatusBadge';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 20;
const STATUS_OPTS = ['all', 'pending', 'confirmed', 'completed', 'cancelled'];

// Payment badge — cash vs Razorpay must be visually distinct
function PaymentBadge({ method, status }) {
  const isCash = method === 'cash_to_guide';
  const isPendingCash = status === 'pending_cash_collection';
  const isCollected = status === 'cod_collected';
  const isPaid = status === 'paid';
  const isRefunded = status === 'refunded';

  if (isCash && isPendingCash) return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: '#fef3c7', color: '#92400e', border: '1px solid #fde68a', borderRadius: 6, padding: '2px 8px', fontSize: 11, fontWeight: 700 }}>
      ⏳ Cash — Pending Collection
    </span>
  );
  if (isCash && isCollected) return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: '#d1fae5', color: '#065f46', border: '1px solid #a7f3d0', borderRadius: 6, padding: '2px 8px', fontSize: 11, fontWeight: 700 }}>
      ✅ Cash — Collected
    </span>
  );
  if (isPaid) return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: '#dcfce7', color: '#166534', border: '1px solid #bbf7d0', borderRadius: 6, padding: '2px 8px', fontSize: 11, fontWeight: 700 }}>
      ✅ Razorpay Paid
    </span>
  );
  if (isRefunded) return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: '#f1f5f9', color: '#475569', border: '1px solid #cbd5e1', borderRadius: 6, padding: '2px 8px', fontSize: 11, fontWeight: 700 }}>
      ↩ Refunded
    </span>
  );
  // Fallback — default to showing what we have
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, background: '#f1f5f9', color: '#334155', border: '1px solid #e2e8f0', borderRadius: 6, padding: '2px 8px', fontSize: 11, fontWeight: 600 }}>
      {method === 'cash_to_guide' ? '💵 Cash to Guide' : '💳 Razorpay'} · {status || '—'}
    </span>
  );
}

function BookingDetail({ booking: initialBooking, onBack, onAction }) {
  const [booking, setBooking] = useState(initialBooking);
  const [note, setNote] = useState(initialBooking.admin_note || '');
  const [saving, setSaving] = useState(false);
  const [confirmAction, setConfirmAction] = useState(null);
  const [pings, setPings] = useState([]);
  const [smsLogs, setSmsLogs] = useState([]);
  const [loadingSafety, setLoadingSafety] = useState(true);
  const [dayLogs, setDayLogs] = useState([]);
  const [loadingLogs, setLoadingLogs] = useState(true);
  const [approvingDay, setApprovingDay] = useState(null);
  const { toast } = useToast();

  const fetchSafetyData = useCallback(async () => {
    try {
      // Fetch location pings for this booking
      const { data: pingData } = await supabase
        .from('location_pings')
        .select('*, profiles(full_name, role)')
        .eq('booking_id', booking.id)
        .order('captured_at', { ascending: false });
      setPings(pingData || []);

      // Fetch emergency SMS logs
      const { data: smsData } = await supabase
        .from('emergency_sms_logs')
        .select('*')
        .eq('booking_id', booking.id)
        .order('created_at', { ascending: false });
      setSmsLogs(smsData || []);

      // Fetch Trip Day Logs for Escrow Stage 2
      try {
        const { data: logData } = await supabase
          .from('trip_day_logs')
          .select('*')
          .eq('booking_id', booking.id)
          .order('day_number', { ascending: true });
        setDayLogs(logData || []);
      } catch (_) {}
    } catch (e) {
      console.error('Safety fetch error:', e);
    } finally {
      setLoadingSafety(false);
      setLoadingLogs(false);
    }
  }, [booking.id]);

  const fetchBookingFresh = useCallback(async () => {
    try {
      const { data } = await supabase
        .from('bookings')
        .select(`*, profiles!traveller_id(full_name, email, phone), agent_details!agent_id(profiles(full_name, phone))`)
        .eq('id', booking.id)
        .single();
      if (data) {
        setBooking(data);
      }
    } catch (_) {}
    fetchSafetyData();
  }, [booking.id, fetchSafetyData]);

  useEffect(() => {
    fetchBookingFresh();

    const ch = supabase.channel(`booking_detail_${booking.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings', filter: `id=eq.${booking.id}` }, () => {
        fetchBookingFresh();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'location_pings' }, () => {
        fetchSafetyData();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trip_day_logs' }, () => {
        fetchSafetyData();
      })
      .subscribe();

    const bc = supabase.channel(`booking_detail_bc_${booking.id}`)
      .on('broadcast', { event: 'refund_status_updated' }, () => fetchBookingFresh())
      .on('broadcast', { event: 'booking_created' }, () => fetchBookingFresh())
      .subscribe();

    const poll = setInterval(fetchBookingFresh, 3000);

    return () => {
      clearInterval(poll);
      supabase.removeChannel(ch);
      supabase.removeChannel(bc);
    };
  }, [booking.id, fetchBookingFresh, fetchSafetyData]);

  async function handleAdminApproveDayPayout(dayNum, dailyAmount) {
    setApprovingDay(dayNum);
    try {
      const { error: pErr } = await supabase
        .from('payouts')
        .insert({
          agent_id: booking.agent_id,
          booking_id: booking.id,
          amount: dailyAmount,
          payout_stage: 2,
          status: 'processing',
          notes: `Escrow Stage 2: Day ${dayNum} Manual Admin Approval`,
          requested_at: new Date().toISOString(),
        });
      if (pErr) throw pErr;

      const newTotal = Number(booking.payout_stage_2_released || 0) + dailyAmount;
      await supabase
        .from('bookings')
        .update({ payout_stage_2_released: newTotal })
        .eq('id', booking.id);

      toast(`Day ${dayNum} payout of ₹${dailyAmount.toLocaleString('en-IN')} approved and queued!`, 'success');
      if (onAction) onAction();
    } catch (err) {
      toast(`Failed to approve day payout: ${err.message}`, 'error');
    } finally {
      setApprovingDay(null);
    }
  }

  async function saveNote() {
    setSaving(true);
    await supabase.from('bookings').update({ admin_note: note }).eq('id', booking.id);
    toast('Note saved', 'success');
    setSaving(false);
  }

  async function resendEmergencySms() {
    const travellerName = booking.profiles?.full_name || 'Traveller';
    const recipient = booking.profiles?.emergency_contact || booking.profiles?.phone || '+91 9876543210';
    const agentName = booking.agent_details?.profiles?.full_name || 'Guide';
    const agentPhone = booking.agent_details?.profiles?.phone || '+91 9988776655';
    const content = `SAFETY ALERT: ${travellerName} trip to ${booking.destination} (${booking.start_date} to ${booking.end_date}) with guide ${agentName} (${agentPhone}). Ref: #${booking.id.slice(0, 8)}`;

    await supabase.from('emergency_sms_logs').insert({
      booking_id: booking.id,
      recipient_number: recipient,
      message_content: content,
      status: 'sent',
    });
    toast('Emergency Contact SMS re-dispatched!', 'success');
    fetchSafetyData();
  }

  // Find latest pings for traveller and agent
  const travellerPing = pings.find(p => p.user_id === booking.traveller_id) || pings[0];
  const agentPing = pings.find(p => p.user_id === booking.agent_id);

  return (
    <div>
      <button className="back-btn" onClick={onBack}>← Back to Bookings</button>
      <div className="card">
        <div className="card-header">
          <div>
            <div className="card-title">Booking #{booking.id.slice(0, 8)}</div>
            <div className="card-meta">{booking.destination} · {booking.start_date} → {booking.end_date}</div>
          </div>
          <div className="action-row">
            <StatusBadge status={booking.status} />
            {booking.status !== 'cancelled' && (
              <button className="btn btn-danger-text btn-sm" onClick={() => setConfirmAction('cancel')}>Force Cancel</button>
            )}
            <button className="btn btn-ghost btn-sm" onClick={() => setConfirmAction('refund')}>Flag for Refund</button>
          </div>
        </div>
        <div className="card-body">
          <div className="detail-grid" style={{ marginBottom: 20 }}>
            <div className="detail-item"><div className="detail-item-label">Traveller</div><div className="detail-item-value">{booking.profiles?.full_name || booking.traveller_id}</div></div>
            <div className="detail-item"><div className="detail-item-label">Agent / Guide</div><div className="detail-item-value">{booking.agent_details?.profiles?.full_name || booking.agent_id}</div></div>
            <div className="detail-item"><div className="detail-item-label">Total Amount</div><div className="detail-item-value" style={{ fontWeight: 700 }}>₹{(booking.total_price || 0).toLocaleString('en-IN')}</div></div>
            <div className="detail-item"><div className="detail-item-label">Created</div><div className="detail-item-value">{new Date(booking.created_at).toLocaleDateString()}</div></div>
            <div className="detail-item" style={{ gridColumn: '1 / -1' }}>
              <div className="detail-item-label">Payment</div>
              <div className="detail-item-value" style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                <PaymentBadge method={booking.payment_method} status={booking.payment_status} />
                {booking.payment_method === 'cash_to_guide' && booking.payment_status === 'pending_cash_collection' && (
                  <button
                    className="btn btn-success btn-sm"
                    onClick={async () => {
                      await supabase.from('bookings').update({ payment_status: 'cod_collected' }).eq('id', booking.id);
                      toast('Cash marked as collected ✅', 'success');
                      onAction();
                    }}
                  >
                    ✅ Mark Cash Collected
                  </button>
                )}
              </div>
            </div>
            {booking.meeting_point && (
              <div className="detail-item" style={{ gridColumn: '1 / -1' }}>
                <div className="detail-item-label">📍 Meeting Point</div>
                <div className="detail-item-value" style={{ fontWeight: 600 }}>{booking.meeting_point}</div>
              </div>
            )}
          </div>

          {/* 🛡️ Dead-Zone Safety & Emergency Dashboard */}
          <div style={{ background: '#f8fafc', border: '1.5px solid #e2e8f0', borderRadius: 12, padding: 18, marginBottom: 20 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 18 }}>🛡️</span>
                <span style={{ fontWeight: 800, fontSize: 15, color: '#0f172a' }}>Dead-Zone Safety & Last Known Location</span>
              </div>
              <button className="btn btn-secondary btn-sm" onClick={resendEmergencySms}>📡 Resend Emergency SMS</button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 16 }}>
              {/* Traveller Ping */}
              <div style={{ background: '#fff', border: '1px solid #cbd5e1', borderRadius: 10, padding: 12 }}>
                <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: '#64748b', marginBottom: 4 }}>Traveller Last Known GPS</div>
                {travellerPing ? (
                  <div>
                    <div style={{ fontWeight: 800, fontSize: 14, color: '#15803d' }}>
                      📍 {Number(travellerPing.latitude).toFixed(4)}° N, {Number(travellerPing.longitude).toFixed(4)}° E
                    </div>
                    <div style={{ fontSize: 12, color: '#64748b', marginTop: 2 }}>
                      Recorded: {new Date(travellerPing.captured_at).toLocaleString()}
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: 12, color: '#94a3b8', italic: true }}>No GPS ping recorded yet</div>
                )}
              </div>

              {/* Agent Ping */}
              <div style={{ background: '#fff', border: '1px solid #cbd5e1', borderRadius: 10, padding: 12 }}>
                <div style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', color: '#64748b', marginBottom: 4 }}>Guide Last Known GPS</div>
                {agentPing ? (
                  <div>
                    <div style={{ fontWeight: 800, fontSize: 14, color: '#0284c7' }}>
                      📍 {Number(agentPing.latitude).toFixed(4)}° N, {Number(agentPing.longitude).toFixed(4)}° E
                    </div>
                    <div style={{ fontSize: 12, color: '#64748b', marginTop: 2 }}>
                      Recorded: {new Date(agentPing.captured_at).toLocaleString()}
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: 12, color: '#94a3b8', italic: true }}>No GPS ping recorded yet</div>
                )}
              </div>
            </div>

            {/* Pre-Shared Trip Plan & Meeting Point */}
            <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10, padding: 14, marginBottom: 14 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: '#334155', marginBottom: 4 }}>Pre-Shared Meeting Point</div>
              <div style={{ fontSize: 13, color: '#0f172a', fontWeight: 600, marginBottom: 10 }}>
                {booking.meeting_point || 'Not specified by guide yet'}
              </div>
              <div style={{ fontSize: 13, fontWeight: 700, color: '#334155', marginBottom: 4 }}>Pre-Shared Trip Plan / Itinerary Route</div>
              <div style={{ fontSize: 12.5, color: '#334155', whiteSpace: 'pre-line', lineHeight: 1.4 }}>
                {booking.trip_plan || 'Not uploaded by guide yet'}
              </div>
            </div>

            {/* Emergency Contact SMS Status */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: '#ecfdf5', border: '1px solid #a7f3d0', borderRadius: 8, padding: '10px 14px' }}>
              <div>
                <span style={{ fontSize: 12, fontWeight: 700, color: '#065f46' }}>Emergency Contact SMS Status: </span>
                <span style={{ fontSize: 12, fontWeight: 800, color: smsLogs.length > 0 ? '#047857' : '#d97706' }}>
                  {smsLogs.length > 0 ? `Sent to ${smsLogs[0].recipient_number} ✓ (${new Date(smsLogs[0].created_at).toLocaleTimeString()})` : 'Pending / Triggered on Confirmation'}
                </span>
              </div>
              {smsLogs.length > 0 && <span className="status-chip status-completed" style={{ fontSize: 11 }}>Logged ✓</span>}
            </div>
          </div>

          {/* 💰 SIMPLIFIED 50% / 50% GUIDE FEE ESCROW RELEASE */}
          {(() => {
            const startD = booking.start_date ? new Date(booking.start_date) : null;
            const endD = booking.end_date ? new Date(booking.end_date) : null;
            const numDays = startD && endD ? Math.max(1, Math.ceil(Math.abs(endD - startD) / (1000 * 60 * 60 * 24)) + 1) : 1;
            const guideFee = Number(booking.guide_fee_total || booking.total_price || 0);
            const startAmt = Math.round(guideFee * 0.5);
            const finalAmt = guideFee - startAmt;
            const dailyCash = Number(booking.estimated_daily_expenses || 1500);

            const startReleased = !!(booking.payout_start_released || booking.payout_stage_1_released);
            const finalReleased = !!(booking.payout_final_released || booking.payout_stage_3_released);

            return (
              <div style={{ background: '#f8fafc', border: '1.5px solid #cbd5e1', borderRadius: 12, padding: 18, marginBottom: 20 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ fontSize: 18 }}>🛡️</span>
                    <div>
                      <span style={{ fontWeight: 800, fontSize: 15, color: '#0f172a' }}>Simplified 50% / 50% Guide Fee Model</span>
                      <div style={{ fontSize: 11, color: '#64748b' }}>
                        Guide Service Fee: ₹{guideFee.toLocaleString('en-IN')} (Only app-charged amount) • {numDays} Day{numDays > 1 ? 's' : ''}
                      </div>
                    </div>
                  </div>
                  <span className={`status-chip ${finalReleased ? 'status-completed' : 'status-active'}`}>
                    {finalReleased ? '100% Fee Released ✓' : startReleased ? '50% Start Released' : 'Held in Escrow'}
                  </span>
                </div>

                {/* Informational Cash Banner */}
                <div style={{ background: '#fef3c7', border: '1px solid #fde68a', borderRadius: 10, padding: '10px 14px', marginBottom: 14, display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontSize: 18 }}>💵</span>
                  <div style={{ fontSize: 12, color: '#92400e', lineHeight: 1.4 }}>
                    <strong>Estimated Cash to Carry by Traveller:</strong> ₹{dailyCash}/day (Total ₹{(dailyCash * numDays).toLocaleString('en-IN')} for {numDays} days).
                    <span style={{ color: '#b45309' }}> Informational budget for stay, food & transport — paid directly, NOT charged through the platform.</span>
                  </div>
                </div>

                {/* STAGE 1: 50% ON START */}
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10, padding: 14, marginBottom: 12 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                    <div style={{ fontWeight: 700, fontSize: 13, color: '#1e293b' }}>
                      Stage 1: Trip Start (50% • ₹{startAmt.toLocaleString('en-IN')})
                    </div>
                    {startReleased ? (
                      <span className="badge badge-green">✓ 50% Start Released</span>
                    ) : (
                      <span className="badge badge-amber">⏳ Pending Dual Confirmation</span>
                    )}
                  </div>
                  <div style={{ fontSize: 12, color: '#475569', display: 'flex', gap: 16 }}>
                    <div>Traveller Start: <strong>{booking.traveller_confirmed_start ? '✓ Confirmed' : 'Waiting'}</strong></div>
                    <div>Guide Start: <strong>{booking.agent_confirmed_start ? '✓ Confirmed' : 'Waiting'}</strong></div>
                    <div>Started At: <strong>{booking.trip_started_at ? new Date(booking.trip_started_at).toLocaleString() : 'Not yet'}</strong></div>
                  </div>
                </div>

                {/* STAGE 2: 50% ON COMPLETION & REVIEW */}
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10, padding: 14 }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: 13, color: '#1e293b' }}>
                        Stage 2: Trip Completion & Review (50% • ₹{finalAmt.toLocaleString('en-IN')})
                      </div>
                      <div style={{ fontSize: 11, color: '#64748b', marginTop: 2 }}>
                        {finalReleased ? '✓ Released upon final traveller review' : 'Releases when traveller submits trip review'}
                      </div>
                    </div>
                    {finalReleased ? (
                      <span className="badge badge-green">✓ 50% Final Released</span>
                    ) : (
                      <span className="badge badge-amber">⏳ Awaiting Trip Completion & Review</span>
                    )}
                  </div>
                </div>
              </div>
            );
          })()}

          {booking.trip_notes && (
            <div className="detail-item" style={{ marginBottom: 16 }}>
              <div className="detail-item-label">Trip Notes (from traveller)</div>
              <div style={{ background: 'var(--paper)', border: '1px solid var(--line)', borderRadius: 8, padding: '10px 14px', fontSize: 13 }}>{booking.trip_notes}</div>
            </div>
          )}

          {/* Refund Management Section */}
          <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: 10, padding: 14, marginBottom: 16 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: '#334155' }}>Refund Status</div>
              <span className={`status-chip ${
                (booking.admin_note || '').includes('REFUND_STATUS:refunded') ? 'status-completed' :
                (booking.admin_note || '').includes('REFUND_STATUS:processing') ? 'status-pending' :
                (booking.admin_note || '').includes('REFUND_STATUS:denied') ? 'status-cancelled' :
                booking.status === 'cancelled' ? 'status-pending' : 'status-active'
              }`}>
                {(booking.admin_note || '').includes('REFUND_STATUS:refunded') ? 'Refunded' :
                 (booking.admin_note || '').includes('REFUND_STATUS:processing') ? 'Processing' :
                 (booking.admin_note || '').includes('REFUND_STATUS:denied') ? 'Denied' :
                 booking.status === 'cancelled' ? 'Refund Requested' : 'None'}
              </span>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
              <button
                className="btn btn-secondary btn-xs"
                onClick={async () => {
                  const updatedNote = `${note.replace(/REFUND_STATUS:\w+/g, '')}\nREFUND_STATUS:processing`.trim();
                  setNote(updatedNote);
                  await supabase.from('bookings').update({ admin_note: updatedNote }).eq('id', booking.id);
                  const ch = supabase.channel('booking_live_status_channel');
                  await ch.subscribe();
                  await ch.send({ type: 'broadcast', event: 'refund_status_updated', payload: { booking_id: booking.id, refund_status: 'processing' } });
                  toast('Refund marked as Processing', 'success');
                  onAction();
                }}
              >
                Mark Processing
              </button>
              <button
                className="btn btn-primary btn-xs"
                onClick={async () => {
                  const updatedNote = `${note.replace(/REFUND_STATUS:\w+/g, '')}\nREFUND_STATUS:refunded`.trim();
                  setNote(updatedNote);
                  await supabase.from('bookings').update({ admin_note: updatedNote }).eq('id', booking.id);
                  const ch = supabase.channel('booking_live_status_channel');
                  await ch.subscribe();
                  await ch.send({ type: 'broadcast', event: 'refund_status_updated', payload: { booking_id: booking.id, refund_status: 'refunded' } });
                  toast('Refund completed and broadcast to traveller', 'success');
                  onAction();
                }}
              >
                Mark Refunded ✓
              </button>
              <button
                className="btn btn-danger-text btn-xs"
                onClick={async () => {
                  const updatedNote = `${note.replace(/REFUND_STATUS:\w+/g, '')}\nREFUND_STATUS:denied`.trim();
                  setNote(updatedNote);
                  await supabase.from('bookings').update({ admin_note: updatedNote }).eq('id', booking.id);
                  const ch = supabase.channel('booking_live_status_channel');
                  await ch.subscribe();
                  await ch.send({ type: 'broadcast', event: 'refund_status_updated', payload: { booking_id: booking.id, refund_status: 'denied' } });
                  toast('Refund denied', 'error');
                  onAction();
                }}
              >
                Deny Refund
              </button>
            </div>
          </div>

          <div className="field-group">
            <label className="field-label">Admin Note (internal only)</label>
            <textarea className="field-input" rows={3} value={note} onChange={e => setNote(e.target.value)} placeholder="Internal notes visible only to admins…" />
            <button className="btn btn-secondary btn-sm" style={{ marginTop: 8 }} onClick={saveNote} disabled={saving}>{saving ? 'Saving…' : 'Save Note'}</button>
          </div>
        </div>
      </div>

      {confirmAction === 'cancel' && (
        <ConfirmDialog
          title="Force Cancel Booking?"
          description="This will cancel the booking and notify both the traveller and agent. This action cannot be undone."
          confirmLabel="Force Cancel"
          confirmClass="btn btn-primary"
          onConfirm={async () => {
            await supabase.from('bookings').update({ status: 'cancelled' }).eq('id', booking.id);
            toast('Booking cancelled', 'success');
            setConfirmAction(null);
            onAction();
          }}
          onCancel={() => setConfirmAction(null)}
        />
      )}
    </div>
  );
}


export default function Bookings() {
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedBooking, setSelectedBooking] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      let supaRows = [];
      try {
        let q = supabase.from('bookings')
          .select(`*, profiles!traveller_id(full_name, email, phone), agent_details!agent_id(profiles(full_name, phone))`);
        q = q.order('created_at', { ascending: false });
        const { data, error: bErr } = await q;
        if (bErr) throw bErr;
        if (data) supaRows = data;
      } catch (err) {
        console.warn('DB Bookings query error:', err.message);
      }

      let merged = [...supaRows];

      if (statusFilter !== 'all') {
        merged = merged.filter(b => (b.status || '').toLowerCase().includes(statusFilter.toLowerCase()));
      }
      if (search.trim()) {
        const s = search.toLowerCase();
        merged = merged.filter(b =>
          (b.destination || '').toLowerCase().includes(s) ||
          (b.agent_details?.profiles?.full_name || b.agent_name || '').toLowerCase().includes(s) ||
          (b.profiles?.full_name || b.profiles?.email || b.traveller_name || '').toLowerCase().includes(s)
        );
      }

      merged.sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));

      const startIdx = (page - 1) * PAGE_SIZE;
      const paginated = merged.slice(startIdx, startIdx + PAGE_SIZE);

      setRows(paginated);
      setTotal(merged.length);
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [page, search, statusFilter]);

  useEffect(() => { fetchData(); }, [fetchData]);

  useEffect(() => {
    // 1. Postgres changes on bookings table
    const ch = supabase.channel('admin-bookings-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, (payload) => {
        console.log('Bookings Realtime update received:', payload);
        fetchData();
      })
      .subscribe((status) => {
        console.log('Bookings subscription status:', status);
      });

    // 2. Broadcast listener for instant booking updates
    const bc = supabase.channel('booking_live_status_channel')
      .on('broadcast', { event: 'booking_created' }, () => fetchData())
      .on('broadcast', { event: 'refund_status_updated' }, () => fetchData())
      .subscribe();

    const globalBc = supabase.channel('global_admin_sync')
      .on('broadcast', { event: 'booking_created' }, () => fetchData())
      .subscribe();

    // 3. Heartbeat polling every 3 seconds + visibility listener
    const poll = setInterval(() => fetchData(), 3000);
    const onVis = () => { if (document.visibilityState === 'visible') fetchData(); };
    document.addEventListener('visibilitychange', onVis);

    return () => {
      clearInterval(poll);
      document.removeEventListener('visibilitychange', onVis);
      supabase.removeChannel(ch);
      supabase.removeChannel(bc);
      supabase.removeChannel(globalBc);
    };
  }, [fetchData]);

  if (selectedBooking) {
    return <BookingDetail booking={selectedBooking} onBack={() => setSelectedBooking(null)} onAction={fetchData} />;
  }

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search by destination…" value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {STATUS_OPTS.map(s => (
              <button key={s} className={`filter-chip${statusFilter === s ? ' active' : ''}`}
                onClick={() => { setStatusFilter(s); setPage(1); }}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>Traveller</th><th>Agent</th><th>Destination</th><th>Dates</th><th>Amount</th><th>Escrow Stages</th><th>Payment</th><th>Status</th>
            </tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={8}><Skeleton rows={8} cols={8} /></td></tr>
                : error ? <tr><td colSpan={8}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={8}>
                    <div className="empty-state"><div className="empty-state-icon">📅</div><div className="empty-state-title">No bookings found</div></div>
                  </td></tr>
                ) : rows.map(b => (
                  <tr key={b.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedBooking(b)}>
                    <td style={{ fontWeight: 600 }}>{b.profiles?.full_name || '—'}</td>
                    <td className="cell-muted">{b.agent_details?.profiles?.full_name || '—'}</td>
                    <td>{b.destination}</td>
                    <td className="cell-muted">{b.start_date} → {b.end_date}</td>
                    <td style={{ fontWeight: 600 }}>₹{(b.total_price || 0).toLocaleString('en-IN')}</td>
                    <td>
                      {b.status === 'cancelled' ? (
                        <span className="badge badge-red">Cancelled</span>
                      ) : b.payout_stage_3_released ? (
                        <span className="badge badge-green">✓ 100% Escrow Released</span>
                      ) : b.payout_stage_1_released ? (
                        <div>
                          <span className="badge badge-purple" style={{ fontSize: 11 }}>
                            {Number(b.payout_stage_2_released || 0) > 0 ? `Stage 2 (₹${Number(b.payout_stage_2_released).toLocaleString('en-IN')})` : 'Stage 1 (30% Released)'}
                          </span>
                        </div>
                      ) : b.traveller_confirmed_start && !b.agent_confirmed_start ? (
                        <span className="badge badge-amber" style={{ fontSize: 11 }}>⚠️ Guide Start Pending</span>
                      ) : (
                        <span className="badge badge-gray" style={{ fontSize: 11 }}>Pending Start</span>
                      )}
                    </td>
                    <td><PaymentBadge method={b.payment_method} status={b.payment_status} /></td>
                    <td><StatusBadge status={b.status} /></td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
      </div>
    </div>
  );
}
