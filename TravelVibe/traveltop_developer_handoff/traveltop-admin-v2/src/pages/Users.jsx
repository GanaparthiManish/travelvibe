import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import StatusBadge from '../components/StatusBadge';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 20;

function UserDetail({ user, onBack }) {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.from('bookings')
      .select('*, agent_details(profiles(full_name))')
      .eq('traveller_id', user.id)
      .order('created_at', { ascending: false })
      .then(({ data }) => { setBookings(data || []); setLoading(false); });
  }, [user.id]);

  return (
    <div>
      <button className="back-btn" onClick={onBack}>← Back to Users</button>
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            {user.photo_url
              ? <img src={user.photo_url} className="avatar" style={{ width: 48, height: 48 }} alt="" />
              : <div className="avatar-fallback" style={{ width: 48, height: 48, fontSize: 16 }}>{(user.full_name || 'U')[0]}</div>
            }
            <div>
              <div style={{ fontWeight: 800, fontSize: 16 }}>{user.full_name || '—'}</div>
              <div className="cell-muted">{user.email} · {user.phone}</div>
              <div className="cell-muted">Joined {new Date(user.created_at).toLocaleDateString()}</div>
            </div>
          </div>
          <StatusBadge status={user.suspended ? 'suspended' : 'active'} />
        </div>
        <div className="card-body">
          <div className="section-title">Booking History ({bookings.length})</div>
          {loading ? <Skeleton rows={3} cols={5} /> : (
            <table style={{ width: '100%' }}>
              <thead><tr>
                <th>Destination</th><th>Agent</th><th>Dates</th><th>Amount</th><th>Status</th>
              </tr></thead>
              <tbody>
                {bookings.length === 0
                  ? <tr><td colSpan={5} style={{ textAlign: 'center', padding: 20, color: 'var(--ink-soft)' }}>No bookings yet</td></tr>
                  : bookings.map(b => (
                    <tr key={b.id}>
                      <td>{b.destination || 'Custom Tour Package'}</td>
                      <td className="cell-muted">{b.agent_details?.profiles?.full_name || '—'}</td>
                      <td className="cell-muted">{b.start_date} → {b.end_date}</td>
                      <td>₹{(b.total_price || 0).toLocaleString('en-IN')}</td>
                      <td><StatusBadge status={b.status} /></td>
                    </tr>
                  ))
                }
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}

export default function Users() {
  const { toast } = useToast();
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedUser, setSelectedUser] = useState(null);
  const [suspendTarget, setSuspendTarget] = useState(null);

  const getSuspendedMap = () => {
    try {
      const raw = localStorage.getItem('admin_user_suspended_map');
      return raw ? JSON.parse(raw) : {};
    } catch (_) { return {}; }
  };

  const saveSuspendedMap = (map) => {
    try {
      localStorage.setItem('admin_user_suspended_map', JSON.stringify(map));
    } catch (_) {}
  };

  const fetchData = useCallback(async () => {
    setLoading(true);
    const suspendedMap = getSuspendedMap();
    try {
      let profilesData = [];
      try {
        let q = supabase.from('profiles').select('*');
        const { data, error: pErr } = await q;
        if (pErr) throw pErr;
        if (data) profilesData = data;
      } catch (err) {
        console.warn('DB profiles query error:', err.message);
      }

      let catalog = profilesData.filter(p => p.role !== 'agent');

      if (search) {
        const s = search.toLowerCase();
        catalog = catalog.filter(u =>
          (u.full_name || '').toLowerCase().includes(s) ||
          (u.email || '').toLowerCase().includes(s) ||
          (u.phone || '').includes(s)
        );
      }

      // Apply persistent suspended state from localStorage
      catalog = catalog.map(u => ({
        ...u,
        suspended: suspendedMap[u.id] !== undefined ? suspendedMap[u.id] : (suspendedMap[u.email] !== undefined ? suspendedMap[u.email] : u.suspended),
      }));

      const startIdx = (page - 1) * PAGE_SIZE;
      const paginated = catalog.slice(startIdx, startIdx + PAGE_SIZE);

      setRows(paginated);
      setTotal(catalog.length);
      setError(null);
    } catch (e) {
      setError(e.message);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => { fetchData(); }, [fetchData]);

  useEffect(() => {
    // 1. Postgres DB changes channel
    const ch = supabase.channel('users_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, fetchData)
      .subscribe();

    // 2. Realtime Broadcast Channel for Live User Logins & Profiles
    const liveStreamCh = supabase.channel('user_live_stream_channel');
    liveStreamCh.on('broadcast', { event: 'user_logged_in' }, (payload) => {
      if (payload && payload.payload) {
        const u = payload.payload;
        const suspendedMap = getSuspendedMap();
        const userObj = {
          ...u,
          suspended: suspendedMap[u.id] !== undefined ? suspendedMap[u.id] : (suspendedMap[u.email] !== undefined ? suspendedMap[u.email] : false),
        };
        setRows((prev) => {
          const idx = prev.findIndex((item) => item.id === userObj.id || item.email === userObj.email);
          if (idx >= 0) {
            const next = [...prev];
            next[idx] = { ...next[idx], ...userObj };
            return next;
          }
          return [userObj, ...prev];
        });
      }
    });
    liveStreamCh.on('broadcast', { event: 'user_profile_updated' }, (payload) => {
      if (payload && payload.payload) {
        const u = payload.payload;
        const suspendedMap = getSuspendedMap();
        const userObj = {
          ...u,
          suspended: suspendedMap[u.id] !== undefined ? suspendedMap[u.id] : (suspendedMap[u.email] !== undefined ? suspendedMap[u.email] : false),
        };
        setRows((prev) => {
          const idx = prev.findIndex((item) => item.id === userObj.id || item.email === userObj.email);
          if (idx >= 0) {
            const next = [...prev];
            next[idx] = { ...next[idx], ...userObj };
            return next;
          }
          return [userObj, ...prev];
        });
      }
    });
    liveStreamCh.subscribe();

    return () => {
      supabase.removeChannel(ch);
      supabase.removeChannel(liveStreamCh);
    };
  }, [fetchData]);

  async function toggleSuspend(user) {
    const nextState = !user.suspended;

    // 1. Update in local state
    setRows(prev => prev.map(u => (u.id === user.id || u.email === user.email) ? { ...u, suspended: nextState } : u));
    if (selectedUser && (selectedUser.id === user.id || selectedUser.email === user.email)) {
      setSelectedUser(prev => ({ ...prev, suspended: nextState }));
    }

    // 2. Persist to localStorage map
    const suspendedMap = getSuspendedMap();
    if (user.id) suspendedMap[user.id] = nextState;
    if (user.email) suspendedMap[user.email] = nextState;
    saveSuspendedMap(suspendedMap);

    // 3. Persist to Supabase profiles table if present
    try {
      await supabase.from('profiles').update({ suspended: nextState }).eq('id', user.id);
    } catch (_) {}

    toast(`User "${user.full_name || user.email}" ${nextState ? 'suspended' : 'reactivated'} successfully.`, nextState ? 'warning' : 'success');
    setSuspendTarget(null);
  }

  if (selectedUser) {
    return <UserDetail user={selectedUser} onBack={() => setSelectedUser(null)} />;
  }

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search by name or email…" value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>User</th><th>Role</th><th>Joined</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={5}><Skeleton rows={8} cols={5} /></td></tr>
                : error ? <tr><td colSpan={5}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={5}><div className="empty-state"><div className="empty-state-icon">👤</div><div className="empty-state-title">No users found</div></div></td></tr>
                ) : rows.map(u => (
                  <tr key={u.id || u.email} style={{ cursor: 'pointer' }} onClick={() => setSelectedUser(u)}>
                    <td>
                      <div className="cell-avatar-wrap">
                        {u.photo_url
                          ? <img src={u.photo_url} className="avatar" alt="" />
                          : <div className="avatar-fallback">{(u.full_name || u.email || 'U')[0].toUpperCase()}</div>
                        }
                        <div>
                          <div style={{ fontWeight: 600 }}>{u.full_name || 'Traveler User'}</div>
                          <div className="cell-muted">{u.email || '—'} · {u.phone || '—'}</div>
                        </div>
                      </div>
                    </td>
                    <td><span className="badge badge-grey">Traveller</span></td>
                    <td className="cell-muted">{u.created_at ? new Date(u.created_at).toLocaleDateString() : '—'}</td>
                    <td><StatusBadge status={u.suspended ? 'suspended' : 'active'} /></td>
                    <td onClick={e => e.stopPropagation()}>
                      <button
                        className={`btn ${u.suspended ? 'btn-success' : 'btn-danger'}`}
                        style={{ padding: '4px 10px', fontSize: 12 }}
                        onClick={() => setSuspendTarget(u)}
                      >
                        {u.suspended ? 'Reactivate' : 'Suspend'}
                      </button>
                    </td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
      </div>

      {suspendTarget && (
        <ConfirmDialog
          title={suspendTarget.suspended ? 'Reactivate User Account' : 'Suspend User Account'}
          message={`Are you sure you want to ${suspendTarget.suspended ? 'reactivate' : 'suspend'} ${suspendTarget.full_name || suspendTarget.email}?`}
          confirmLabel={suspendTarget.suspended ? 'Reactivate' : 'Suspend'}
          danger={!suspendTarget.suspended}
          onConfirm={() => toggleSuspend(suspendTarget)}
          onCancel={() => setSuspendTarget(null)}
        />
      )}
    </div>
  );
}
