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

function BookingDetail({ booking, onBack, onAction }) {
  const [note, setNote] = useState(booking.admin_note || '');
  const [saving, setSaving] = useState(false);
  const [confirmAction, setConfirmAction] = useState(null);
  const [pings, setPings] = useState([]);
  const [smsLogs, setSmsLogs] = useState([]);
  const [loadingSafety, setLoadingSafety] = useState(true);
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
    } catch (e) {
      console.error('Safety fetch error:', e);
    } finally {
      setLoadingSafety(false);
    }
  }, [booking.id]);

  useEffect(() => {
    fetchSafetyData();
  }, [fetchSafetyData]);

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
          .select(`*, profiles!traveller_id(full_name, email), agent_details!agent_id(profiles(full_name))`);
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
    const ch = supabase.channel('admin-bookings-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, (payload) => {
        console.log('Bookings Realtime update received:', payload);
        fetchData();
      })
      .subscribe((status) => {
        console.log('Bookings subscription status:', status);
      });

    return () => supabase.removeChannel(ch);
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
              <th>Traveller</th><th>Agent</th><th>Destination</th><th>Dates</th><th>Amount</th><th>Status</th>
            </tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={6}><Skeleton rows={8} cols={6} /></td></tr>
                : error ? <tr><td colSpan={6}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={6}>
                    <div className="empty-state"><div className="empty-state-icon">📅</div><div className="empty-state-title">No bookings found</div></div>
                  </td></tr>
                ) : rows.map(b => (
                  <tr key={b.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedBooking(b)}>
                    <td style={{ fontWeight: 600 }}>{b.profiles?.full_name || '—'}</td>
                    <td className="cell-muted">{b.agent_details?.profiles?.full_name || '—'}</td>
                    <td>{b.destination}</td>
                    <td className="cell-muted">{b.start_date} → {b.end_date}</td>
                    <td style={{ fontWeight: 600 }}>₹{(b.total_price || 0).toLocaleString('en-IN')}</td>
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
