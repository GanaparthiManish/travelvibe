import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import StatusBadge from '../components/StatusBadge';

const TARGETS = [
  { value: 'all', label: 'All Users' },
  { value: 'agents', label: 'Agents Only' },
  { value: 'travellers', label: 'Travellers Only' },
];

const LOCAL_STORAGE_KEY = 'travelvibe_announcements_history';

export default function Announcements() {
  const { toast } = useToast();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [target, setTarget] = useState('all');
  const [sending, setSending] = useState(false);

  const [history, setHistory] = useState(() => {
    try {
      const saved = localStorage.getItem(LOCAL_STORAGE_KEY);
      return saved ? JSON.parse(saved) : [];
    } catch (_) {
      return [];
    }
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Edit Modal State
  const [editingItem, setEditingItem] = useState(null);
  const [editTitle, setEditTitle] = useState('');
  const [editBody, setEditBody] = useState('');
  const [editTarget, setEditTarget] = useState('all');
  const [savingEdit, setSavingEdit] = useState(false);

  const saveToLocal = (items) => {
    try {
      localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(items));
    } catch (_) {}
  };

  const fetchHistory = useCallback(async () => {
    setLoading(true);
    try {
      let dbAnnouncements = [];
      try {
        const { data, error: err } = await supabase
          .from('announcements')
          .select('*')
          .order('sent_at', { ascending: false })
          .limit(50);
        if (!err && data) {
          dbAnnouncements = data;
        }
      } catch (dbErr) {
        console.warn('Announcements fetch notice:', dbErr);
      }

      // Merge DB announcements with local announcements
      let localAnnouncements = [];
      try {
        const saved = localStorage.getItem(LOCAL_STORAGE_KEY);
        if (saved) localAnnouncements = JSON.parse(saved);
      } catch (_) {}

      // Combine and deduplicate by ID or (title + body)
      const map = new Map();
      dbAnnouncements.forEach(a => map.set(a.id, a));
      localAnnouncements.forEach(a => {
        if (!map.has(a.id)) map.set(a.id, a);
      });

      const merged = Array.from(map.values()).sort(
        (a, b) => new Date(b.sent_at || 0) - new Date(a.sent_at || 0)
      );

      setHistory(merged);
      saveToLocal(merged);
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchHistory();
  }, [fetchHistory]);

  // Helper to reliably broadcast to all clients
  const broadcastAnnouncement = async (payload) => {
    const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
    const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

    // 1. WebSocket broadcast on announcements_rt
    try {
      const ch = supabase.channel(`ann_broadcast_${Date.now()}`);
      ch.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          ch.send({
            type: 'broadcast',
            event: 'new_announcement',
            payload,
          }).then(() => {
            setTimeout(() => ch.unsubscribe(), 2000);
          });
        }
      });
    } catch (e) {
      console.warn('WebSocket broadcast error:', e);
    }

    // 2. WebSocket broadcast on user_live_stream_channel
    try {
      const streamCh = supabase.channel(`stream_broadcast_${Date.now()}`);
      streamCh.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          streamCh.send({
            type: 'broadcast',
            event: 'new_announcement',
            payload,
          }).then(() => {
            setTimeout(() => streamCh.unsubscribe(), 2000);
          });
        }
      });
    } catch (e) {
      console.warn('Stream broadcast error:', e);
    }

    // 3. HTTP REST broadcast for instant delivery
    try {
      await fetch(`${supabaseUrl}/realtime/v1/api/broadcast`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: anonKey,
          Authorization: `Bearer ${anonKey}`,
        },
        body: JSON.stringify({
          messages: [
            {
              topic: 'realtime:announcements_rt',
              event: 'new_announcement',
              payload,
            },
            {
              topic: 'realtime:user_live_stream_channel',
              event: 'new_announcement',
              payload,
            },
          ],
        }),
      });
    } catch (_) {}
  };

  async function send() {
    if (!title.trim() || !body.trim()) {
      toast('Title and body are required', 'error');
      return;
    }
    setSending(true);

    const generatedId = `ann_${Date.now()}`;
    const sentAt = new Date().toISOString();
    let finalId = generatedId;

    try {
      // 1. Try DB persist
      try {
        const { data: ann, error: annErr } = await supabase
          .from('announcements')
          .insert({
            title: title.trim(),
            body: body.trim(),
            target,
            sent_at: sentAt,
          })
          .select()
          .single();

        if (!annErr && ann?.id) {
          finalId = ann.id;
        }
      } catch (dbE) {
        console.warn('Announcements table insert notice:', dbE);
      }

      // 2. Broadcast live to all connected mobile & web clients
      const payload = {
        id: finalId,
        title: title.trim(),
        body: body.trim(),
        target,
        sent_at: sentAt,
      };
      await broadcastAnnouncement(payload);

      // 3. Send individual notifications if users available
      try {
        let userQuery = supabase.from('profiles').select('id');
        if (target === 'agents') userQuery = userQuery.eq('role', 'agent');
        else if (target === 'travellers') userQuery = userQuery.eq('role', 'traveller');
        const { data: users } = await userQuery;

        if (users && users.length > 0) {
          const notifications = users.map((u) => ({
            user_id: u.id,
            type: 'announcement',
            title: `📢 ${title.trim()}`,
            body: body.trim(),
            related_id: finalId.startsWith('ann_') ? null : finalId,
            is_read: false,
            created_at: sentAt,
          }));

          for (let i = 0; i < notifications.length; i += 200) {
            try {
              await supabase.from('notifications').insert(notifications.slice(i, i + 200));
            } catch (_) {}
          }
        }
      } catch (_) {}

      // 4. Update local state & storage immediately
      const newRecord = {
        id: finalId,
        title: title.trim(),
        body: body.trim(),
        target,
        sent_at: sentAt,
      };

      setHistory((prev) => {
        const next = [newRecord, ...prev.filter((p) => p.id !== finalId)];
        saveToLocal(next);
        return next;
      });

      toast('Announcement broadcasted to all users in real-time ✓', 'success');
      setTitle('');
      setBody('');
      setTarget('all');
    } catch (e) {
      toast(e.message || 'Failed to broadcast announcement', 'error');
    } finally {
      setSending(false);
    }
  }

  // Open Edit Modal
  const openEdit = (item) => {
    setEditingItem(item);
    setEditTitle(item.title || '');
    setEditBody(item.body || '');
    setEditTarget(item.target || 'all');
  };

  // Save Edit
  const handleSaveEdit = async () => {
    if (!editingItem) return;
    if (!editTitle.trim() || !editBody.trim()) {
      toast('Title and body cannot be empty', 'error');
      return;
    }

    setSavingEdit(true);
    try {
      // 1. Update in Supabase if valid UUID
      try {
        await supabase
          .from('announcements')
          .update({
            title: editTitle.trim(),
            body: editBody.trim(),
            target: editTarget,
          })
          .eq('id', editingItem.id);
      } catch (err) {
        console.warn('Update in DB notice:', err);
      }

      // 2. Broadcast updated announcement
      const updatedPayload = {
        id: editingItem.id,
        title: editTitle.trim(),
        body: editBody.trim(),
        target: editTarget,
        sent_at: editingItem.sent_at,
      };
      await broadcastAnnouncement(updatedPayload);

      // 3. Update local state
      setHistory((prev) => {
        const next = prev.map((item) =>
          item.id === editingItem.id
            ? { ...item, title: editTitle.trim(), body: editBody.trim(), target: editTarget }
            : item
        );
        saveToLocal(next);
        return next;
      });

      toast('Announcement updated successfully ✓', 'success');
      setEditingItem(null);
    } catch (e) {
      toast('Error updating announcement: ' + e.message, 'error');
    } finally {
      setSavingEdit(false);
    }
  };

  // Delete Announcement
  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this announcement?')) {
      return;
    }

    try {
      // 1. Delete from Supabase
      try {
        await supabase.from('announcements').delete().eq('id', id);
      } catch (err) {
        console.warn('Delete in DB notice:', err);
      }

      // 2. Update local state
      setHistory((prev) => {
        const next = prev.filter((item) => item.id !== id);
        saveToLocal(next);
        return next;
      });

      toast('Announcement deleted successfully ✓', 'success');
    } catch (e) {
      toast('Error deleting announcement: ' + e.message, 'error');
    }
  };

  return (
    <div>
      {/* Send Form */}
      <div className="card" style={{ marginBottom: 24 }}>
        <div className="card-header">
          <div>
            <div className="card-title">Send Announcement</div>
            <div className="card-meta">Push a notification to all or specific users instantly in real-time</div>
          </div>
        </div>
        <div className="card-body">
          <div className="field-group">
            <label className="field-label">Title *</label>
            <input
              className="field-input"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g. Special Holiday Offer & System Update!"
              maxLength={120}
            />
          </div>
          <div className="field-group">
            <label className="field-label">Message Body *</label>
            <textarea
              className="field-input"
              rows={4}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Write your announcement message here…"
              maxLength={500}
            />
            <div className="field-hint">{body.length}/500 characters</div>
          </div>
          <div className="field-group" style={{ maxWidth: 260 }}>
            <label className="field-label">Target Audience</label>
            <select
              className="field-input"
              value={target}
              onChange={(e) => setTarget(e.target.value)}
            >
              {TARGETS.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </div>
          <button
            className="btn btn-primary"
            onClick={send}
            disabled={sending || !title.trim() || !body.trim()}
          >
            {sending ? (
              <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span
                  style={{
                    width: 14,
                    height: 14,
                    border: '2px solid rgba(255,255,255,0.4)',
                    borderTopColor: 'white',
                    borderRadius: '50%',
                    animation: 'spin 0.7s linear infinite',
                    display: 'inline-block',
                  }}
                />
                Broadcasting…
              </span>
            ) : (
              '📢 Send Announcement'
            )}
          </button>
        </div>
      </div>

      {/* History */}
      <div className="card">
        <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div className="card-title">Announcement History</div>
            <div className="card-meta">Total sent: {history.length}</div>
          </div>
          <button
            className="btn btn-secondary btn-sm"
            onClick={fetchHistory}
            disabled={loading}
          >
            🔄 Refresh
          </button>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Message</th>
                <th>Target</th>
                <th>Sent At</th>
                <th style={{ textAlign: 'right', minWidth: 140 }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && history.length === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <Skeleton rows={4} cols={5} />
                  </td>
                </tr>
              ) : error && history.length === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <ErrorState message={error} onRetry={fetchHistory} />
                  </td>
                </tr>
              ) : history.length === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <div className="empty-state">
                      <div className="empty-state-icon">📢</div>
                      <div className="empty-state-title">No announcements sent yet</div>
                      <div className="empty-state-sub">
                        Send your first announcement using the form above.
                      </div>
                    </div>
                  </td>
                </tr>
              ) : (
                history.map((a) => (
                  <tr key={a.id}>
                    <td style={{ fontWeight: 600, color: 'var(--text-main)' }}>{a.title}</td>
                    <td className="cell-muted" style={{ maxWidth: 300 }}>
                      <div
                        style={{
                          overflow: 'hidden',
                          display: '-webkit-box',
                          WebkitLineClamp: 2,
                          WebkitBoxOrient: 'vertical',
                        }}
                      >
                        {a.body}
                      </div>
                    </td>
                    <td>
                      <span
                        className={`badge ${
                          a.target === 'all'
                            ? 'badge-blue'
                            : a.target === 'agents'
                            ? 'badge-purple'
                            : 'badge-green'
                        }`}
                      >
                        {TARGETS.find((t) => t.value === a.target)?.label || a.target}
                      </span>
                    </td>
                    <td className="cell-muted">
                      {a.sent_at ? new Date(a.sent_at).toLocaleString() : 'Just now'}
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div style={{ display: 'inline-flex', gap: 8 }}>
                        <button
                          className="btn btn-secondary btn-sm"
                          style={{ padding: '4px 10px', fontSize: 12 }}
                          onClick={() => openEdit(a)}
                          title="Edit Announcement"
                        >
                          ✏️ Edit
                        </button>
                        <button
                          className="btn btn-danger btn-sm"
                          style={{
                            padding: '4px 10px',
                            fontSize: 12,
                            backgroundColor: '#fee2e2',
                            color: '#dc2626',
                            border: '1px solid #fca5a5',
                          }}
                          onClick={() => handleDelete(a.id)}
                          title="Delete Announcement"
                        >
                          🗑️ Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Edit Modal */}
      {editingItem && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 16,
          }}
        >
          <div
            className="card"
            style={{
              width: '100%',
              maxWidth: 520,
              backgroundColor: '#fff',
              borderRadius: 12,
              boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)',
            }}
          >
            <div className="card-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="card-title">Edit Announcement</div>
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setEditingItem(null)}
                style={{ fontSize: 18, padding: '2px 8px' }}
              >
                ✕
              </button>
            </div>
            <div className="card-body">
              <div className="field-group">
                <label className="field-label">Title *</label>
                <input
                  className="field-input"
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  maxLength={120}
                />
              </div>
              <div className="field-group">
                <label className="field-label">Message Body *</label>
                <textarea
                  className="field-input"
                  rows={4}
                  value={editBody}
                  onChange={(e) => setEditBody(e.target.value)}
                  maxLength={500}
                />
                <div className="field-hint">{editBody.length}/500 characters</div>
              </div>
              <div className="field-group" style={{ maxWidth: 260 }}>
                <label className="field-label">Target Audience</label>
                <select
                  className="field-input"
                  value={editTarget}
                  onChange={(e) => setEditTarget(e.target.value)}
                >
                  {TARGETS.map((t) => (
                    <option key={t.value} value={t.value}>
                      {t.label}
                    </option>
                  ))}
                </select>
              </div>
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12, marginTop: 16 }}>
                <button
                  className="btn btn-secondary"
                  onClick={() => setEditingItem(null)}
                  disabled={savingEdit}
                >
                  Cancel
                </button>
                <button
                  className="btn btn-primary"
                  onClick={handleSaveEdit}
                  disabled={savingEdit || !editTitle.trim() || !editBody.trim()}
                >
                  {savingEdit ? 'Saving…' : 'Save Changes'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}

