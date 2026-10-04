import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 15;

export default function SOSIncidents() {
  const { toast } = useToast();
  const [incidents, setIncidents] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState('all'); // all, open, resolved, false_alarm
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [adminNotes, setAdminNotes] = useState('');
  const [actionLoading, setActionLoading] = useState(false);
  const [suspendTarget, setSuspendTarget] = useState(null); // { type: 'agent'|'traveller', id, name }

  const fetchIncidents = useCallback(async () => {
    setLoading(true);
    try {
      let q = supabase
        .from('sos_incidents')
        .select('*', { count: 'exact' });

      if (statusFilter !== 'all') {
        q = q.eq('status', statusFilter);
      }

      q = q.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

      const { data, count, error: err } = await q;
      if (err) throw err;

      // Enrich with booking, traveller and agent profile data
      const bookingIds = [...new Set((data || []).map(i => i.booking_id).filter(Boolean))];
      const userIds = [...new Set((data || []).map(i => i.triggered_by).filter(Boolean))];

      let bookingMap = {};
      let userMap = {};

      if (bookingIds.length > 0) {
        const { data: bData } = await supabase
          .from('bookings')
          .select('id, destination, start_date, end_date, total_price, status, traveller_id, agent_id')
          .in('id', bookingIds);

        if (bData) {
          const participantIds = [...new Set(bData.flatMap(b => [b.traveller_id, b.agent_id]).filter(Boolean))];
          const { data: pData } = await supabase
            .from('profiles')
            .select('id, full_name, email, phone, emergency_contact, suspended')
            .in('id', participantIds);

          let pMap = {};
          if (pData) pData.forEach(p => { pMap[p.id] = p; });

          bData.forEach(b => {
            bookingMap[b.id] = {
              ...b,
              traveller: pMap[b.traveller_id] || null,
              agent: pMap[b.agent_id] || null,
            };
          });
        }
      }

      if (userIds.length > 0) {
        const { data: uData } = await supabase
          .from('profiles')
          .select('id, full_name, email, phone, role')
          .in('id', userIds);
        if (uData) uData.forEach(u => { userMap[u.id] = u; });
      }

      const enriched = (data || []).map(i => ({
        ...i,
        booking: bookingMap[i.booking_id] || null,
        triggered_by_profile: userMap[i.triggered_by] || null,
      }));

      setIncidents(enriched);
      setTotal(count || 0);
      setError(null);
    } catch (err) {
      console.error('Error fetching SOS incidents:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter]);

  useEffect(() => {
    fetchIncidents();
  }, [fetchIncidents]);

  // Real-time subscription to sos_incidents
  useEffect(() => {
    const ch = supabase
      .channel('admin_sos_realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'sos_incidents' }, (payload) => {
        toast('🚨 SOS Alert update received!', 'error');
        fetchIncidents();
      })
      .on('broadcast', { event: 'sos_triggered' }, (payload) => {
        toast('🚨 NEW LIVE EMERGENCY SOS TRIGGERED!', 'error');
        fetchIncidents();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(ch);
    };
  }, [fetchIncidents]);

  const openIncidentsCount = incidents.filter(i => i.status === 'open').length;

  const handleUpdateStatus = async (incidentId, newStatus) => {
    setActionLoading(true);
    try {
      const payload = {
        status: newStatus,
        admin_notes: adminNotes,
      };
      if (newStatus === 'resolved' || newStatus === 'false_alarm') {
        payload.resolved_at = new Date().toISOString();
      }

      const { error: updErr } = await supabase
        .from('sos_incidents')
        .update(payload)
        .eq('id', incidentId);

      if (updErr) throw updErr;

      toast(`Incident marked as ${newStatus.replace('_', ' ')}`, 'success');
      setSelectedIncident(null);
      setAdminNotes('');
      fetchIncidents();
    } catch (err) {
      toast('Failed to update incident: ' + err.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSuspendUser = async (target) => {
    setActionLoading(true);
    try {
      if (target.type === 'agent') {
        await supabase.from('agent_details').update({ suspended: true }).eq('id', target.id);
        await supabase.from('profiles').update({ suspended: true }).eq('id', target.id);
        toast(`Guide ${target.name} has been suspended immediately.`, 'warning');
      } else {
        await supabase.from('profiles').update({ suspended: true }).eq('id', target.id);
        toast(`Traveller ${target.name} has been suspended immediately.`, 'warning');
      }
      setSuspendTarget(null);
      fetchIncidents();
    } catch (err) {
      toast('Failed to suspend user: ' + err.message, 'error');
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* LOUD UNMISSABLE ACTIVE ALERTS BANNER */}
      {openIncidentsCount > 0 && (
        <div style={{
          background: 'linear-gradient(135deg, #b91c1c 0%, #dc2626 100%)',
          borderRadius: 14,
          padding: '16px 20px',
          color: '#fff',
          boxShadow: '0 8px 24px rgba(220, 38, 38, 0.35)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          animation: 'pulse 2s infinite'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <span style={{ fontSize: 28 }}>🚨</span>
            <div>
              <div style={{ fontSize: 16, fontWeight: 900, letterSpacing: '0.02em', textTransform: 'uppercase' }}>
                URGENT: {openIncidentsCount} ACTIVE EMERGENCY SOS INCIDENT{openIncidentsCount > 1 ? 'S' : ''} OPEN
              </div>
              <div style={{ fontSize: 13, color: '#fee2e2', fontWeight: 600 }}>
                Real-time device coordinates received. Immediate review & emergency dispatch required!
              </div>
            </div>
          </div>
          <button
            className="btn"
            style={{ background: '#fff', color: '#dc2626', fontWeight: 900, border: 'none', padding: '8px 16px', borderRadius: 10 }}
            onClick={() => setStatusFilter('open')}
          >
            Filter Open Alerts ⚡
          </button>
        </div>
      )}

      {/* Main Table Card */}
      <div className="card">
        <div className="table-controls">
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <span style={{ fontWeight: 800, fontSize: 15, color: 'var(--ink)' }}>
              Emergency Safety Center
            </span>
            <span className="badge badge-red" style={{ fontWeight: 800 }}>
              {total} Total Incidents
            </span>
          </div>

          <div style={{ display: 'flex', gap: 6 }}>
            {['all', 'open', 'resolved', 'false_alarm'].map(s => (
              <button
                key={s}
                className={`filter-chip${statusFilter === s ? ' active' : ''}`}
                style={statusFilter === s && s === 'open' ? { background: '#dc2626', color: '#fff', borderColor: '#dc2626' } : {}}
                onClick={() => { setStatusFilter(s); setPage(1); }}
              >
                {s === 'all' ? 'All' : s === 'open' ? '🚨 Open Only' : s === 'false_alarm' ? 'False Alarms' : 'Resolved'}
              </button>
            ))}
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Status</th>
                <th>Triggered By</th>
                <th>Booking Details</th>
                <th>GPS Coordinates</th>
                <th>Reported Time</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={6}><Skeleton rows={6} cols={6} /></td></tr>
              ) : error ? (
                <tr><td colSpan={6}><ErrorState message={error} onRetry={fetchIncidents} /></td></tr>
              ) : incidents.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <div className="empty-state">
                      <div className="empty-state-icon">🛡️</div>
                      <div className="empty-state-title">No SOS incidents recorded</div>
                      <div className="empty-state-desc">All trips are currently operating safely without active emergency flags.</div>
                    </div>
                  </td>
                </tr>
              ) : (
                incidents.map((inc) => {
                  const isOpen = inc.status === 'open';
                  const booking = inc.booking;
                  const coords = inc.last_known_lat && inc.last_known_lng
                    ? `${Number(inc.last_known_lat).toFixed(4)}° N, ${Number(inc.last_known_lng).toFixed(4)}° E`
                    : 'GPS Unavailable';

                  return (
                    <tr
                      key={inc.id}
                      style={{
                        background: isOpen ? '#fff5f5' : 'transparent',
                        fontWeight: isOpen ? 600 : 400,
                      }}
                    >
                      <td>
                        <span
                          className={`badge ${
                            isOpen ? 'badge-red' : inc.status === 'resolved' ? 'badge-green' : 'badge-gray'
                          }`}
                          style={{ fontWeight: 800, textTransform: 'uppercase' }}
                        >
                          <span className="badge-dot" />
                          {inc.status === 'open' ? '🚨 OPEN / URGENT' : inc.status.replace('_', ' ')}
                        </span>
                      </td>

                      <td>
                        <div style={{ fontWeight: 700, color: 'var(--ink)' }}>
                          {inc.triggered_by_profile?.full_name || 'User'}
                        </div>
                        <div style={{ fontSize: 11, color: 'var(--ink-soft)', textTransform: 'capitalize' }}>
                          Role: <strong style={{ color: inc.triggered_by_role === 'agent' ? '#8B5CF6' : '#E8741F' }}>{inc.triggered_by_role}</strong>
                        </div>
                      </td>

                      <td>
                        {booking ? (
                          <div>
                            <div style={{ fontWeight: 700, color: 'var(--ink)' }}>{booking.destination}</div>
                            <div style={{ fontSize: 11, color: 'var(--ink-soft)' }}>
                              Traveller: {booking.traveller?.full_name || '—'} • Guide: {booking.agent?.full_name || '—'}
                            </div>
                          </div>
                        ) : (
                          <span className="cell-muted">Booking #{inc.booking_id?.slice(0, 8) || '—'}</span>
                        )}
                      </td>

                      <td>
                        {inc.last_known_lat ? (
                          <div>
                            <div style={{ fontWeight: 700, color: '#dc2626' }}>📍 {coords}</div>
                            <a
                              href={`https://www.google.com/maps?q=${inc.last_known_lat},${inc.last_known_lng}`}
                              target="_blank"
                              rel="noreferrer"
                              style={{ fontSize: 11, color: '#4338ca', fontWeight: 700, textDecoration: 'underline' }}
                            >
                              Open Live Pin ↗
                            </a>
                          </div>
                        ) : (
                          <span className="cell-muted">No GPS</span>
                        )}
                      </td>

                      <td className="cell-muted">
                        {new Date(inc.created_at).toLocaleString()}
                      </td>

                      <td>
                        <button
                          className={`btn ${isOpen ? 'btn-primary' : 'btn-secondary'} btn-xs`}
                          style={isOpen ? { background: '#dc2626', borderColor: '#b91c1c' } : {}}
                          onClick={() => {
                            setSelectedIncident(inc);
                            setAdminNotes(inc.admin_notes || '');
                          }}
                        >
                          View & Handle ↗
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
      </div>

      {/* INCIDENT DETAIL & DISPATCH MODAL */}
      {selectedIncident && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setSelectedIncident(null)}>
          <div className="modal" style={{ maxWidth: 700, border: '2px solid #ef4444' }}>
            <div className="modal-header" style={{ background: '#fef2f2', borderBottom: '1px solid #fecaca' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 22 }}>🚨</span>
                <div>
                  <div className="modal-title" style={{ color: '#991b1b', fontWeight: 900 }}>
                    Emergency SOS Incident #{selectedIncident.id.slice(0, 8)}
                  </div>
                  <div style={{ fontSize: 12, color: '#b91c1c', fontWeight: 600 }}>
                    Triggered at {new Date(selectedIncident.created_at).toLocaleString()} by {selectedIncident.triggered_by_profile?.full_name} ({selectedIncident.triggered_by_role})
                  </div>
                </div>
              </div>
              <button className="modal-close" onClick={() => setSelectedIncident(null)}>✕</button>
            </div>

            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {/* Location Card */}
              <div style={{ background: '#f8fafc', border: '1px solid #cbd5e1', borderRadius: 10, padding: 14 }}>
                <div style={{ fontWeight: 800, fontSize: 13, color: '#0f172a', marginBottom: 6 }}>
                  📍 Incident Location & Emergency Response Links
                </div>
                {selectedIncident.last_known_lat && selectedIncident.last_known_lng ? (
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 700, color: '#dc2626', marginBottom: 8 }}>
                      Coordinates: {Number(selectedIncident.last_known_lat).toFixed(5)}° N, {Number(selectedIncident.last_known_lng).toFixed(5)}° E
                    </div>
                    <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                      <a
                        href={`https://www.google.com/maps?q=${selectedIncident.last_known_lat},${selectedIncident.last_known_lng}`}
                        target="_blank"
                        rel="noreferrer"
                        className="btn btn-secondary btn-xs"
                        style={{ color: '#1e40af', borderColor: '#bfdbfe' }}
                      >
                        🗺️ Open Pin on Google Maps ↗
                      </a>
                      <a
                        href={`https://www.google.com/maps/search/police+station/@${selectedIncident.last_known_lat},${selectedIncident.last_known_lng},15z`}
                        target="_blank"
                        rel="noreferrer"
                        className="btn btn-secondary btn-xs"
                        style={{ color: '#dc2626', borderColor: '#fecaca' }}
                      >
                        🚔 Find Nearest Police Stations ↗
                      </a>
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: 12, color: '#94a3b8' }}>
                    GPS coordinates were not provided with this alert. Refer to booking meeting point & itinerary below.
                  </div>
                )}
              </div>

              {/* Both Parties Information */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                {/* Traveller Box */}
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10, padding: 12 }}>
                  <div style={{ fontSize: 11, fontWeight: 800, color: '#E8741F', textTransform: 'uppercase', marginBottom: 4 }}>
                    Traveller Information
                  </div>
                  <div style={{ fontWeight: 700, fontSize: 13 }}>{selectedIncident.booking?.traveller?.full_name || 'Traveller'}</div>
                  <div style={{ fontSize: 12, color: '#475569' }}>Phone: <strong>{selectedIncident.booking?.traveller?.phone || '—'}</strong></div>
                  <div style={{ fontSize: 12, color: '#475569' }}>Email: {selectedIncident.booking?.traveller?.email || '—'}</div>
                  <div style={{ fontSize: 12, color: '#dc2626', fontWeight: 600, marginTop: 4 }}>
                    Emergency Contact: {selectedIncident.booking?.traveller?.emergency_contact || 'None registered'}
                  </div>
                  <button
                    className="btn btn-secondary btn-xs"
                    style={{ marginTop: 8, color: '#dc2626', borderColor: '#fecaca' }}
                    onClick={() => setSuspendTarget({
                      type: 'traveller',
                      id: selectedIncident.booking?.traveller_id,
                      name: selectedIncident.booking?.traveller?.full_name || 'Traveller',
                    })}
                  >
                    🚫 Suspend Traveller
                  </button>
                </div>

                {/* Agent Box */}
                <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10, padding: 12 }}>
                  <div style={{ fontSize: 11, fontWeight: 800, color: '#8B5CF6', textTransform: 'uppercase', marginBottom: 4 }}>
                    Guide Information
                  </div>
                  <div style={{ fontWeight: 700, fontSize: 13 }}>{selectedIncident.booking?.agent?.full_name || 'Guide'}</div>
                  <div style={{ fontSize: 12, color: '#475569' }}>Phone: <strong>{selectedIncident.booking?.agent?.phone || '—'}</strong></div>
                  <div style={{ fontSize: 12, color: '#475569' }}>Email: {selectedIncident.booking?.agent?.email || '—'}</div>
                  <button
                    className="btn btn-secondary btn-xs"
                    style={{ marginTop: 8, color: '#dc2626', borderColor: '#fecaca' }}
                    onClick={() => setSuspendTarget({
                      type: 'agent',
                      id: selectedIncident.booking?.agent_id,
                      name: selectedIncident.booking?.agent?.full_name || 'Guide',
                    })}
                  >
                    🚫 Suspend Guide
                  </button>
                </div>
              </div>

              {/* Admin Resolution & Action Notes */}
              <div className="field-group">
                <label className="field-label" style={{ fontWeight: 700 }}>
                  Admin Action & Resolution Notes
                </label>
                <textarea
                  className="field-input"
                  rows={3}
                  value={adminNotes}
                  onChange={e => setAdminNotes(e.target.value)}
                  placeholder="Record actions taken, contact with local authorities, or rationale for resolution…"
                />
              </div>
            </div>

            <div className="modal-footer" style={{ display: 'flex', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  className="btn btn-secondary"
                  disabled={actionLoading}
                  onClick={() => handleUpdateStatus(selectedIncident.id, 'false_alarm')}
                >
                  Mark False Alarm
                </button>
              </div>

              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn btn-ghost" onClick={() => setSelectedIncident(null)}>Close</button>
                <button
                  className="btn btn-primary"
                  style={{ background: '#059669', borderColor: '#047857' }}
                  disabled={actionLoading}
                  onClick={() => handleUpdateStatus(selectedIncident.id, 'resolved')}
                >
                  ✓ Mark Resolved
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Suspend Confirmation Dialog */}
      {suspendTarget && (
        <ConfirmDialog
          title={`Suspend ${suspendTarget.name}?`}
          description={`Are you sure you want to suspend this ${suspendTarget.type}? Their account will be locked immediately and they will be blocked from accessing active bookings or payouts.`}
          confirmLabel="Suspend Account"
          confirmClass="btn btn-primary"
          onConfirm={() => handleSuspendUser(suspendTarget)}
          onCancel={() => setSuspendTarget(null)}
        />
      )}
    </div>
  );
}
