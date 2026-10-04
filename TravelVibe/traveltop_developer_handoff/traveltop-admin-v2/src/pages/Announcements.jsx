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

export default function Announcements() {
  const { toast } = useToast();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [target, setTarget] = useState('all');
  const [sending, setSending] = useState(false);

  const [history, setHistory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchHistory = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error: err } = await supabase
        .from('announcements')
        .select('*')
        .order('sent_at', { ascending: false })
        .limit(50);
      if (err) throw err;
      setHistory(data || []);
      setError(null);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchHistory(); }, [fetchHistory]);

  async function send() {
    if (!title.trim() || !body.trim()) {
      toast('Title and body are required', 'error');
      return;
    }
    setSending(true);
    try {
      // Insert announcement record
      const { data: ann, error: annErr } = await supabase
        .from('announcements')
        .insert({ title, body, target, sent_at: new Date().toISOString() })
        .select().single();
      if (annErr) throw annErr;

      // Fetch target users
      let userQuery = supabase.from('profiles').select('id');
      if (target === 'agents') userQuery = userQuery.eq('role', 'agent');
      else if (target === 'travellers') userQuery = userQuery.eq('role', 'traveller');

      const { data: users } = await userQuery;

      // Bulk insert notifications
      if (users && users.length > 0) {
        const notifications = users.map(u => ({
          user_id: u.id,
          type: 'announcement',
          title,
          body,
          related_id: ann.id,
          is_read: false,
          created_at: new Date().toISOString(),
        }));

        // Insert in batches of 500 to avoid payload limits
        for (let i = 0; i < notifications.length; i += 500) {
          await supabase.from('notifications').insert(notifications.slice(i, i + 500));
        }
      }

      // Broadcast announcement in real-time
      try {
        const annCh = supabase.channel('announcements_rt');
        await annCh.send({
          type: 'broadcast',
          event: 'new_announcement',
          payload: { title, body, target },
        });
      } catch (_) {}

      toast(`Announcement sent to ${users?.length || 0} users ✓`, 'success');
      setTitle(''); setBody(''); setTarget('all');

      fetchHistory();
    } catch (e) {
      toast(e.message, 'error');
    }
    setSending(false);
  }

  return (
    <div>
      {/* Send Form */}
      <div className="card" style={{ marginBottom: 24 }}>
        <div className="card-header">
          <div>
            <div className="card-title">Send Announcement</div>
            <div className="card-meta">Push a notification to all or specific users instantly</div>
          </div>
        </div>
        <div className="card-body">
          <div className="field-group">
            <label className="field-label">Title *</label>
            <input className="field-input" value={title} onChange={e => setTitle(e.target.value)}
              placeholder="e.g. New feature available!" maxLength={120} />
          </div>
          <div className="field-group">
            <label className="field-label">Message Body *</label>
            <textarea className="field-input" rows={4} value={body} onChange={e => setBody(e.target.value)}
              placeholder="Write your announcement message here…" maxLength={500} />
            <div className="field-hint">{body.length}/500 characters</div>
          </div>
          <div className="field-group" style={{ maxWidth: 260 }}>
            <label className="field-label">Target Audience</label>
            <select className="field-input" value={target} onChange={e => setTarget(e.target.value)}>
              {TARGETS.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>
          </div>
          <button className="btn btn-primary" onClick={send} disabled={sending || !title.trim() || !body.trim()}>
            {sending ? (
              <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ width: 14, height: 14, border: '2px solid rgba(255,255,255,0.4)', borderTopColor: 'white', borderRadius: '50%', animation: 'spin 0.7s linear infinite', display: 'inline-block' }} />
                Sending…
              </span>
            ) : '📢 Send Announcement'}
          </button>
        </div>
      </div>

      {/* History */}
      <div className="card">
        <div className="card-header">
          <div className="card-title">Announcement History</div>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>Title</th>
              <th>Message</th>
              <th>Target</th>
              <th>Sent At</th>
            </tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={4}><Skeleton rows={5} cols={4} /></td></tr>
                : error ? <tr><td colSpan={4}><ErrorState message={error} onRetry={fetchHistory} /></td></tr>
                : history.length === 0 ? (
                  <tr><td colSpan={4}>
                    <div className="empty-state">
                      <div className="empty-state-icon">📢</div>
                      <div className="empty-state-title">No announcements sent yet</div>
                    </div>
                  </td></tr>
                ) : history.map(a => (
                  <tr key={a.id}>
                    <td style={{ fontWeight: 600 }}>{a.title}</td>
                    <td className="cell-muted" style={{ maxWidth: 300 }}>
                      <div style={{ overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                        {a.body}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${a.target === 'all' ? 'badge-blue' : a.target === 'agents' ? 'badge-purple' : 'badge-green'}`}>
                        {TARGETS.find(t => t.value === a.target)?.label || a.target}
                      </span>
                    </td>
                    <td className="cell-muted">{new Date(a.sent_at).toLocaleString()}</td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
