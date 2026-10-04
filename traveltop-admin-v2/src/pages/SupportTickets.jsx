import React, { useEffect, useState, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import StatusBadge from '../components/StatusBadge';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';

const PAGE_SIZE = 20;

const STATUS_OPTIONS = ['open', 'in_progress', 'resolved'];
const TYPE_OPTIONS = ['General', 'Booking Issue', 'Payment Problem', 'Agent Complaint', 'Safety Issue', 'Refund Request', 'Technical Bug', 'Other'];

function statusBadgeClass(status) {
  if (status === 'resolved') return 'badge badge-green';
  if (status === 'in_progress') return 'badge badge-blue';
  return 'badge badge-amber';
}

function isSafetyIssue(type) {
  return type?.toLowerCase().includes('safety');
}

export default function SupportTickets() {
  const { addToast } = useToast();
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [selected, setSelected] = useState(null); // detail view
  const [updatingId, setUpdatingId] = useState(null);
  const [internalNote, setInternalNote] = useState('');
  const [savingNote, setSavingNote] = useState(false);
  const channelRef = useRef(null);

  const fetchTickets = useCallback(async () => {
    try {
      setError(null);
      let query = supabase
        .from('support_tickets')
        .select('*', { count: 'exact' })
        .order('created_at', { ascending: false })
        .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

      if (filterStatus !== 'all') query = query.eq('status', filterStatus);
      if (search.trim()) {
        query = query.or(`subject.ilike.%${search.trim()}%,message.ilike.%${search.trim()}%,category.ilike.%${search.trim()}%`);
      }

      const { data, count, error: err } = await query;
      if (err) throw err;

      // Fetch profiles for user_ids
      const userIds = [...new Set((data || []).map(t => t.user_id).filter(id => id && id.length > 20))];
      let profilesMap = {};
      if (userIds.length > 0) {
        const { data: pData } = await supabase.from('profiles').select('id, full_name, email, photo_url').in('id', userIds);
        if (pData) {
          pData.forEach(p => { profilesMap[p.id] = p; });
        }
      }

      const formatted = (data || []).map(t => ({
        ...t,
        type: t.type || t.category || 'General',
        description: t.description || t.message || t.subject || '—',
        profiles: profilesMap[t.user_id] || null,
      }));

      setTickets(formatted);
      setTotal(count || 0);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [page, filterStatus, search]);

  useEffect(() => {
    setLoading(true);
    fetchTickets();
  }, [fetchTickets]);

  // Real-time subscription
  useEffect(() => {
    if (channelRef.current) supabase.removeChannel(channelRef.current);
    const channel = supabase.channel('support_tickets_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'support_tickets' }, fetchTickets)
      .subscribe();
    channelRef.current = channel;
    return () => { if (channelRef.current) supabase.removeChannel(channelRef.current); };
  }, [fetchTickets]);

  async function updateStatus(ticketId, newStatus) {
    setUpdatingId(ticketId);
    const { error: err } = await supabase
      .from('support_tickets')
      .update({ status: newStatus })
      .eq('id', ticketId);
    setUpdatingId(null);
    if (err) { addToast('Failed to update status', 'error'); return; }
    addToast(`Status updated to ${newStatus.replace('_', ' ')}`, 'success');
    if (selected?.id === ticketId) setSelected(s => ({ ...s, status: newStatus }));
    fetchTickets();
  }

  async function saveNote() {
    if (!selected) return;
    setSavingNote(true);
    const { error: err } = await supabase
      .from('support_tickets')
      .update({ internal_note: internalNote })
      .eq('id', selected.id);
    setSavingNote(false);
    if (err) { addToast('Failed to save note', 'error'); return; }
    addToast('Internal note saved', 'success');
    setSelected(s => ({ ...s, internal_note: internalNote }));
    fetchTickets();
  }

  function openDetail(ticket) {
    setSelected(ticket);
    setInternalNote(ticket.internal_note || '');
  }

  const totalPages = Math.ceil(total / PAGE_SIZE);

  if (error && !tickets.length) return <ErrorState message={error} onRetry={fetchTickets} />;

  // Detail view
  if (selected) {
    return (
      <div>
        <button className="back-btn" onClick={() => setSelected(null)}>
          ← Back to Tickets
        </button>

        <div className="card">
          <div className="card-header">
            <div>
              <div className="card-title" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                {isSafetyIssue(selected.type) && (
                  <span className="badge badge-red" style={{ fontSize: 10, gap: 3 }}>
                    🚨 Safety Issue
                  </span>
                )}
                Ticket #{selected.id?.slice(-8).toUpperCase()}
              </div>
              <div className="card-meta">Submitted {new Date(selected.created_at).toLocaleString()}</div>
            </div>
            <span className={statusBadgeClass(selected.status)}>
              {selected.status?.replace('_', ' ')}
            </span>
          </div>
          <div className="card-body">
            <div className="detail-grid" style={{ marginBottom: 24 }}>
              <div className="detail-item">
                <div className="detail-item-label">User</div>
                <div className="detail-item-value" style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div className="avatar-fallback" style={{ width: 28, height: 28, fontSize: 11 }}>
                    {(selected.profiles?.full_name || 'U')[0].toUpperCase()}
                  </div>
                  <div>
                    <div style={{ fontWeight: 600 }}>{selected.profiles?.full_name || 'Unknown User'}</div>
                    <div className="cell-muted">{selected.profiles?.email || '—'}</div>
                  </div>
                </div>
              </div>
              <div className="detail-item">
                <div className="detail-item-label">Issue Type</div>
                <div className="detail-item-value">
                  {isSafetyIssue(selected.type)
                    ? <span style={{ color: 'var(--red)', fontWeight: 700 }}>🚨 {selected.type}</span>
                    : selected.type || '—'}
                </div>
              </div>
              <div className="detail-item">
                <div className="detail-item-label">Status</div>
                <div className="detail-item-value">
                  <select
                    className="field-input"
                    style={{ width: 'auto', padding: '5px 10px' }}
                    value={selected.status || 'open'}
                    onChange={e => updateStatus(selected.id, e.target.value)}
                    disabled={updatingId === selected.id}
                  >
                    {STATUS_OPTIONS.map(s => (
                      <option key={s} value={s}>{s.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase())}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="detail-item">
                <div className="detail-item-label">Created</div>
                <div className="detail-item-value">{new Date(selected.created_at).toLocaleString()}</div>
              </div>
            </div>

            <div className="field-group">
              <div className="detail-item-label" style={{ marginBottom: 8 }}>Description</div>
              <div style={{
                background: 'var(--paper)', border: '1px solid var(--line)',
                borderRadius: 8, padding: '14px 16px', fontSize: 13, lineHeight: 1.6, color: 'var(--ink)'
              }}>
                {selected.description || 'No description provided.'}
              </div>
            </div>

            <hr className="divider" />

            <div className="field-group">
              <label className="field-label">Internal Note (admin only)</label>
              <textarea
                className="field-input"
                rows={4}
                placeholder="Add an internal note for the team..."
                value={internalNote}
                onChange={e => setInternalNote(e.target.value)}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 10 }}>
                <button className="btn btn-primary" onClick={saveNote} disabled={savingNote}>
                  {savingNote ? 'Saving…' : 'Save Note'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
        <div>
          <div style={{ fontSize: 18, fontWeight: 800, color: 'var(--ink)' }}>Support Tickets</div>
          <div style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 2 }}>
            {total} ticket{total !== 1 ? 's' : ''} total
          </div>
        </div>
      </div>

      <div className="card">
        {/* Controls */}
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input
              className="search-input"
              placeholder="Search descriptions…"
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
          {['all', ...STATUS_OPTIONS].map(s => (
            <button
              key={s}
              className={`filter-chip${filterStatus === s ? ' active' : ''}`}
              onClick={() => { setFilterStatus(s); setPage(1); }}
            >
              {s === 'all' ? 'All' : s.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase())}
            </button>
          ))}
        </div>

        {/* Table */}
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th>Type</th>
                <th>Description</th>
                <th>Status</th>
                <th>Date</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <tr key={i}>
                    {Array.from({ length: 6 }).map((_, j) => (
                      <td key={j}><div className="skeleton skeleton-text" /></td>
                    ))}
                  </tr>
                ))
              ) : tickets.length === 0 ? (
                <tr>
                  <td colSpan={6}>
                    <div className="empty-state">
                      <div className="empty-state-icon">🎧</div>
                      <div className="empty-state-title">No support tickets</div>
                      <div className="empty-state-desc">When users submit support requests, they'll appear here.</div>
                    </div>
                  </td>
                </tr>
              ) : (
                tickets.map(ticket => (
                  <tr key={ticket.id} style={{ cursor: 'pointer' }} onClick={() => openDetail(ticket)}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <div className="avatar-fallback" style={{ width: 28, height: 28, fontSize: 11 }}>
                          {(ticket.profiles?.full_name || 'U')[0].toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontWeight: 600, fontSize: 13 }}>{ticket.profiles?.full_name || 'Unknown'}</div>
                          <div className="cell-muted">{ticket.profiles?.email || '—'}</div>
                        </div>
                      </div>
                    </td>
                    <td>
                      {isSafetyIssue(ticket.type) ? (
                        <span style={{ color: 'var(--red)', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4 }}>
                          🚨 {ticket.type}
                        </span>
                      ) : (
                        <span>{ticket.type || '—'}</span>
                      )}
                    </td>
                    <td>
                      <span style={{ color: 'var(--ink-soft)', fontSize: 12 }}>
                        {ticket.description?.length > 80
                          ? ticket.description.slice(0, 80) + '…'
                          : ticket.description || '—'}
                      </span>
                    </td>
                    <td onClick={e => e.stopPropagation()}>
                      <select
                        className="field-input"
                        style={{ width: 'auto', padding: '4px 8px', fontSize: 12 }}
                        value={ticket.status || 'open'}
                        onChange={e => updateStatus(ticket.id, e.target.value)}
                        disabled={updatingId === ticket.id}
                      >
                        {STATUS_OPTIONS.map(s => (
                          <option key={s} value={s}>{s.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase())}</option>
                        ))}
                      </select>
                    </td>
                    <td className="cell-muted">{new Date(ticket.created_at).toLocaleDateString()}</td>
                    <td onClick={e => e.stopPropagation()}>
                      <button className="btn btn-ghost btn-sm" onClick={() => openDetail(ticket)}>
                        View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <Pagination page={page} totalPages={totalPages} total={total} pageSize={PAGE_SIZE} onChange={setPage} />
        )}
      </div>
    </div>
  );
}
