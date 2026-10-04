import React, { useEffect, useState, useCallback, useRef } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import StatusBadge from '../components/StatusBadge';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 20;
const POLL_INTERVAL_MS = 3000; // 3-second polling — fast enough to feel real-time

// ─── Merge a new/updated user into existing rows without duplicates ─────────
function mergeUser(prev, incoming) {
  const incomingEmail = (incoming.email || '').trim().toLowerCase();
  const incomingName = (incoming.full_name || '').trim();

  const idx = prev.findIndex((u) => {
    if (incoming.id && u.id === incoming.id) return true;
    if (incomingEmail && (u.email || '').trim().toLowerCase() === incomingEmail) return true;
    if (incomingName && incomingName !== 'User' && incomingName !== 'Traveller' && (u.full_name || '').trim() === incomingName) return true;
    return false;
  });

  if (idx >= 0) {
    const next = [...prev];
    next[idx] = { ...next[idx], ...incoming };
    return next;
  }
  return [incoming, ...prev]; // prepend — newest first
}

function UserDetail({ user, onBack }) {
  const [activeTab, setActiveTab] = useState('bookings');
  const [bookings, setBookings] = useState([]);
  const [orders, setOrders] = useState([]);
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isLiveDetail, setIsLiveDetail] = useState(false);

  const loadUserData = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      // 1. Gather all profile IDs linked to this user (by ID, email, or phone)
      let ids = [user.id];
      if (user.email || user.phone) {
        try {
          let profileQuery = supabase.from('profiles').select('id');
          if (user.email && user.phone) {
            profileQuery = profileQuery.or(`email.eq.${user.email},phone.eq.${user.phone}`);
          } else if (user.email) {
            profileQuery = profileQuery.eq('email', user.email);
          } else if (user.phone) {
            profileQuery = profileQuery.eq('phone', user.phone);
          }
          const { data: matchedProfiles } = await profileQuery;
          if (matchedProfiles?.length) {
            ids = Array.from(new Set([...ids, ...matchedProfiles.map(p => p.id)]));
          }
        } catch (mErr) {
          console.warn('[UserDetail] profile matching warning:', mErr);
        }
      }

      // 2. Load Bookings (as traveller or guide)
      let bData = [];
      try {
        const { data: bRes } = await supabase
          .from('bookings')
          .select('*, agent_details(profiles(full_name))')
          .or(`traveller_id.in.(${ids.join(',')}),agent_id.in.(${ids.join(',')})`)
          .order('created_at', { ascending: false });
        if (bRes) bData = bRes;
      } catch (bErr) {
        console.warn('[UserDetail] bookings join error, fallback to simple query:', bErr);
        try {
          const { data: bFallback } = await supabase
            .from('bookings')
            .select('*')
            .or(`traveller_id.in.(${ids.join(',')}),agent_id.in.(${ids.join(',')})`)
            .order('created_at', { ascending: false });
          if (bFallback) bData = bFallback;
        } catch (_) {}
      }

      // 3. Load Shop Orders (strictly using traveller_id IN ids)
      let oData = [];
      try {
        const { data: ordRes } = await supabase
          .from('orders')
          .select('*')
          .in('traveller_id', ids)
          .order('created_at', { ascending: false });
        if (ordRes) oData = ordRes;
      } catch (oErr) {
        console.warn('[UserDetail] orders fetch warning:', oErr);
      }

      // 4. Load Support Tickets (by user_id IN ids)
      let tData = [];
      try {
        const { data: tickRes } = await supabase
          .from('support_tickets')
          .select('*')
          .in('user_id', ids)
          .order('created_at', { ascending: false });
        if (tickRes) tData = tickRes;
      } catch (tErr) {
        console.warn('[UserDetail] tickets fetch warning:', tErr);
      }

      setBookings(bData);
      setOrders(oData);
      setTickets(tData);
    } catch (e) {
      console.error('Error loading user details:', e);
    } finally {
      if (!silent) setLoading(false);
    }
  }, [user.id, user.email, user.phone]);

  useEffect(() => {
    let active = true;
    loadUserData(false);

    // Layer 1: Supabase Postgres Realtime changes on orders, bookings, support_tickets
    const pgChannel = supabase
      .channel(`user_detail_pg_${user.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        if (active) loadUserData(true);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, () => {
        if (active) loadUserData(true);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'support_tickets' }, () => {
        if (active) loadUserData(true);
      })
      .subscribe((status) => {
        if (active) setIsLiveDetail(status === 'SUBSCRIBED');
      });

    // Layer 2: Broadcast events from shop, checkout & booking flows
    const bcOrders = supabase
      .channel(`user_detail_orders_bc_${user.id}`)
      .on('broadcast', { event: 'order_placed' }, () => {
        if (active) loadUserData(true);
      })
      .on('broadcast', { event: 'order_status_updated' }, () => {
        if (active) loadUserData(true);
      })
      .subscribe();

    const bcBookings = supabase
      .channel(`user_detail_bookings_bc_${user.id}`)
      .on('broadcast', { event: 'booking_created' }, () => {
        if (active) loadUserData(true);
      })
      .on('broadcast', { event: 'refund_status_updated' }, () => {
        if (active) loadUserData(true);
      })
      .subscribe();

    const globalSync = supabase
      .channel(`user_detail_sync_${user.id}`)
      .on('broadcast', { event: 'order_placed' }, () => active && loadUserData(true))
      .on('broadcast', { event: 'booking_created' }, () => active && loadUserData(true))
      .subscribe();

    // Layer 3: 3-second heartbeat polling fallback
    const poll = setInterval(() => {
      if (active) loadUserData(true);
    }, 3000);

    return () => {
      active = false;
      clearInterval(poll);
      supabase.removeChannel(pgChannel);
      supabase.removeChannel(bcOrders);
      supabase.removeChannel(bcBookings);
      supabase.removeChannel(globalSync);
    };
  }, [loadUserData, user.id]);

  const summarizeItems = (items) => {
    if (!items) return '—';
    try {
      const parsed = typeof items === 'string' ? JSON.parse(items) : items;
      if (Array.isArray(parsed)) return parsed.map(i => i.name || i.product_name || 'Item').join(', ');
      return String(items);
    } catch { return String(items); }
  };

  return (
    <div>
      <button className="back-btn" onClick={onBack}>← Back to Users</button>
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            {user.photo_url
              ? <img src={user.photo_url} className="avatar" style={{ width: 52, height: 52 }} alt="" />
              : <div className="avatar-fallback" style={{ width: 52, height: 52, fontSize: 18 }}>{(user.full_name || user.email || 'U')[0].toUpperCase()}</div>
            }
            <div>
              <div style={{ fontWeight: 800, fontSize: 17 }}>{user.full_name || 'Traveler User'}</div>
              <div className="cell-muted">{user.email || '—'} · {user.phone || 'No phone added'}</div>
              <div className="cell-muted">Joined {user.created_at ? new Date(user.created_at).toLocaleDateString() : '—'}</div>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              fontSize: 12, fontWeight: 700,
              padding: '4px 10px', borderRadius: 20,
              background: isLiveDetail ? 'rgba(34,197,94,0.1)' : 'rgba(234,179,8,0.1)',
              color: isLiveDetail ? '#16a34a' : '#ca8a04',
              border: `1px solid ${isLiveDetail ? 'rgba(34,197,94,0.3)' : 'rgba(234,179,8,0.3)'}`
            }}>
              <span style={{
                width: 7, height: 7, borderRadius: '50%',
                background: isLiveDetail ? '#22c55e' : '#eab308',
                boxShadow: isLiveDetail ? '0 0 0 2px rgba(34,197,94,0.3)' : 'none'
              }} />
              {isLiveDetail ? 'Live Sync Active' : 'Connecting Realtime…'}
            </span>
            <StatusBadge status={user.suspended ? 'suspended' : 'active'} />
          </div>
        </div>

        <div className="tabs" style={{ marginTop: 12 }}>
          <div className={`tab ${activeTab === 'bookings' ? 'active' : ''}`} onClick={() => setActiveTab('bookings')}>
            Booked Trips <span className="tab-count">{bookings.length}</span>
          </div>
          <div className={`tab ${activeTab === 'orders' ? 'active' : ''}`} onClick={() => setActiveTab('orders')}>
            Shop Orders <span className="tab-count">{orders.length}</span>
          </div>
          <div className={`tab ${activeTab === 'tickets' ? 'active' : ''}`} onClick={() => setActiveTab('tickets')}>
            Support &amp; Refunds <span className="tab-count">{tickets.length}</span>
          </div>
        </div>

        <div className="card-body">
          {loading ? <Skeleton rows={4} cols={5} /> : (
            <>
              {activeTab === 'bookings' && (
                <table style={{ width: '100%' }}>
                  <thead><tr>
                    <th>Destination</th><th>Guide / Agent</th><th>Dates</th><th>Amount</th><th>Status</th>
                  </tr></thead>
                  <tbody>
                    {bookings.length === 0
                      ? <tr><td colSpan={5} style={{ textAlign: 'center', padding: 24, color: 'var(--ink-soft)' }}>No trip bookings found for this user</td></tr>
                      : bookings.map(b => (
                        <tr key={b.id}>
                          <td style={{ fontWeight: 600 }}>{b.destination || 'Tour Package'}</td>
                          <td className="cell-muted">{b.agent_details?.profiles?.full_name || 'Guide'}</td>
                          <td className="cell-muted">{b.start_date} → {b.end_date}</td>
                          <td style={{ fontWeight: 700 }}>₹{(b.total_price || 0).toLocaleString('en-IN')}</td>
                          <td><StatusBadge status={b.status} /></td>
                        </tr>
                      ))
                    }
                  </tbody>
                </table>
              )}
              {activeTab === 'orders' && (
                <table style={{ width: '100%' }}>
                  <thead><tr>
                    <th>Order ID</th><th>Items Purchased</th><th>Total</th><th>Date</th><th>Status</th>
                  </tr></thead>
                  <tbody>
                    {orders.length === 0
                      ? <tr><td colSpan={5} style={{ textAlign: 'center', padding: 24, color: 'var(--ink-soft)' }}>No shop orders placed by this user</td></tr>
                      : orders.map(o => (
                        <tr key={o.id}>
                          <td style={{ fontWeight: 700, fontSize: 12 }}>#{o.id}</td>
                          <td style={{ maxWidth: 220 }}>{summarizeItems(o.items)}</td>
                          <td style={{ fontWeight: 700 }}>₹{(o.total_amount || o.total || 0).toLocaleString('en-IN')}</td>
                          <td className="cell-muted">{o.created_at ? new Date(o.created_at).toLocaleDateString() : '—'}</td>
                          <td><StatusBadge status={o.status} /></td>
                        </tr>
                      ))
                    }
                  </tbody>
                </table>
              )}
              {activeTab === 'tickets' && (
                <table style={{ width: '100%' }}>
                  <thead><tr>
                    <th>Description</th><th>Date Created</th><th>Status</th>
                  </tr></thead>
                  <tbody>
                    {tickets.length === 0
                      ? <tr><td colSpan={3} style={{ textAlign: 'center', padding: 24, color: 'var(--ink-soft)' }}>No support tickets raised</td></tr>
                      : tickets.map(t => (
                        <tr key={t.id}>
                          <td style={{ fontWeight: 600 }}>{t.description || 'Support Request'}</td>
                          <td className="cell-muted">{t.created_at ? new Date(t.created_at).toLocaleDateString() : '—'}</td>
                          <td><StatusBadge status={t.status || 'open'} /></td>
                        </tr>
                      ))
                    }
                  </tbody>
                </table>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default function Users() {
  const { toast } = useToast();
  const [allUsers, setAllUsers] = useState([]);   // full unfiltered cache
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedUser, setSelectedUser] = useState(null);
  const [suspendTarget, setSuspendTarget] = useState(null);
  const [isLive, setIsLive] = useState(false);
  const [newUserCount, setNewUserCount] = useState(0);
  const searchRef = useRef(search);
  const pageRef = useRef(page);
  searchRef.current = search;
  pageRef.current = page;

  // ── Helpers ─────────────────────────────────────────────────────────────────
  const getSuspendedMap = () => {
    try { return JSON.parse(localStorage.getItem('admin_user_suspended_map') || '{}'); }
    catch (_) { return {}; }
  };
  const saveSuspendedMap = (map) => {
    try { localStorage.setItem('admin_user_suspended_map', JSON.stringify(map)); } catch (_) {}
  };

  // Re-apply search & pagination whenever data, search, or page changes
  const applyView = useCallback((catalog, q, pg) => {
    let filtered = catalog;
    if (q) {
      const s = q.toLowerCase();
      filtered = catalog.filter(u =>
        (u.full_name || '').toLowerCase().includes(s) ||
        (u.email || '').toLowerCase().includes(s) ||
        (u.phone || '').includes(s)
      );
    }
    const start = (pg - 1) * PAGE_SIZE;
    setRows(filtered.slice(start, start + PAGE_SIZE));
    setTotal(filtered.length);
  }, []);

  useEffect(() => {
    applyView(allUsers, search, page);
  }, [search, page, allUsers, applyView]);

  // ── Full DB fetch ──────────────────────────────────────────────────────────
  const fetchData = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    const suspendedMap = getSuspendedMap();
    try {
      // Fetch ONLY travellers — agents belong in the Agents page
      const { data, error: pErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('role', 'traveller')
        .order('created_at', { ascending: false });
      if (pErr) throw pErr;

      // Deduplicate travellers by email or unique name so a user who logged in multiple times only appears once
      const seen = new Set();
      const uniqueUsers = [];
      for (const u of (data || [])) {
        const emailKey = (u.email || '').trim().toLowerCase();
        const nameKey = (u.full_name || '').trim();
        const key = emailKey.length > 0
          ? `email:${emailKey}`
          : (nameKey.length > 0 && nameKey !== 'User' && nameKey !== 'Traveller' ? `name:${nameKey}` : `id:${u.id}`);
        if (!seen.has(key)) {
          seen.add(key);
          uniqueUsers.push(u);
        }
      }

      const catalog = uniqueUsers
        .map(u => ({
          ...u,
          suspended: suspendedMap[u.id] !== undefined
            ? suspendedMap[u.id]
            : (suspendedMap[u.email] !== undefined ? suspendedMap[u.email] : (u.suspended || false)),
        }));

      setAllUsers(catalog);
      setError(null);
    } catch (e) {
      if (!silent) setError(e.message);
      console.warn('[Users] fetchData error:', e.message);
    } finally {
      if (!silent) setLoading(false);
    }
  }, []);

  // ── Initial load ───────────────────────────────────────────────────────────
  useEffect(() => { fetchData(); }, [fetchData]);

  // ── 3-second polling + visibility-based instant refresh ────────────────────
  useEffect(() => {
    const poll = setInterval(() => fetchData(true), POLL_INTERVAL_MS);
    // Instantly refresh when the browser tab becomes visible again
    const onVisible = () => { if (document.visibilityState === 'visible') fetchData(true); };
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      clearInterval(poll);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [fetchData]);

  // ── Realtime subscriptions ─────────────────────────────────────────────────
  useEffect(() => {
    const suspendedMap = getSuspendedMap();

    // Layer 1: Postgres Changes
    const pgChannel = supabase
      .channel('admin_users_pg_rt_v2')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'profiles' }, (payload) => {
        const u = payload.new;
        if (!u) return;
        const userObj = { ...u, suspended: suspendedMap[u.id] !== undefined ? suspendedMap[u.id] : (u.suspended || false) };
        setAllUsers(prev => mergeUser(prev, userObj));
        setNewUserCount(n => n + 1);
        toast(`🆕 New user: ${u.full_name || u.email || 'Unknown'}`, 'success');
      })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'profiles' }, (payload) => {
        const u = payload.new;
        if (!u) return;
        setAllUsers(prev => mergeUser(prev, u));
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        fetchData(true);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, () => {
        fetchData(true);
      })
      .subscribe((status) => {
        console.log('[Users] Realtime postgres status:', status);
        setIsLive(status === 'SUBSCRIBED');
      });

    // Layer 2: Broadcast from Flutter and Web app (via HTTP REST & websocket broadcast)
    const broadcastChannel = supabase
      .channel('user_live_stream_channel')
      .on('broadcast', { event: 'user_logged_in' }, (payload) => {
        // HTTP broadcast wraps payload differently — handle both formats
        const u = payload?.payload ?? payload?.data ?? payload;
        if (!u || typeof u !== 'object') return;
        const email = u.email || u.new?.email;
        const id = u.id || u.new?.id;
        if (!email && !id) return;
        const userObj = { ...(u.new || u), suspended: suspendedMap[id] !== undefined ? suspendedMap[id] : false };
        console.log('[Users] Broadcast user_logged_in received:', userObj);
        setAllUsers(prev => {
          const exists = prev.some(x => (id && x.id === id) || (email && x.email === email));
          if (!exists) {
            setNewUserCount(n => n + 1);
            toast(`🟢 Live: ${userObj.full_name || email || 'New user'}`, 'success');
          }
          // Also trigger a silent DB fetch to get any fields not in the broadcast
          setTimeout(() => fetchData(true), 500);
          return mergeUser(prev, userObj);
        });
      })
      .on('broadcast', { event: 'user_profile_updated' }, (payload) => {
        const u = payload?.payload ?? payload?.data ?? payload;
        if (!u || typeof u !== 'object') return;
        setAllUsers(prev => mergeUser(prev, u.new || u));
      })
      .subscribe((status) => {
        console.log('[Users] Broadcast channel status:', status);
      });

    // Layer 3: Global sync channel for cross-app events
    const globalSyncChannel = supabase
      .channel('users_global_admin_sync')
      .on('broadcast', { event: 'order_placed' }, () => {
        fetchData(true);
      })
      .on('broadcast', { event: 'booking_created' }, () => {
        fetchData(true);
      })
      .subscribe();

    return () => {
      supabase.removeChannel(pgChannel);
      supabase.removeChannel(broadcastChannel);
      supabase.removeChannel(globalSyncChannel);
    };
  }, []); // eslint-disable-line

  // ── Suspend / Reactivate ───────────────────────────────────────────────────
  async function toggleSuspend(user) {
    const nextState = !user.suspended;
    setAllUsers(prev => prev.map(u =>
      (u.id === user.id || u.email === user.email) ? { ...u, suspended: nextState } : u
    ));
    if (selectedUser && (selectedUser.id === user.id || selectedUser.email === user.email)) {
      setSelectedUser(prev => ({ ...prev, suspended: nextState }));
    }
    const suspendedMap = getSuspendedMap();
    if (user.id) suspendedMap[user.id] = nextState;
    if (user.email) suspendedMap[user.email] = nextState;
    saveSuspendedMap(suspendedMap);
    try { 
      await supabase.from('profiles').update({ suspended: nextState }).eq('id', user.id); 
      // If user is an agent, also update agent_details table
      if (user.role === 'agent') {
        await supabase.from('agent_details').update({ suspended: nextState }).eq('id', user.id);
      }
      // Broadcast instant sync event
      const syncCh = supabase.channel('global_admin_sync');
      syncCh.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          syncCh.send({
            type: 'broadcast',
            event: 'agent_status_changed',
            payload: { id: user.id, action: nextState ? 'suspend' : 'unsuspend', suspended: nextState, timestamp: Date.now() }
          });
        }
      });
    } catch (_) {}
    toast(`User "${user.full_name || user.email}" ${nextState ? 'suspended' : 'reactivated'}.`, nextState ? 'warning' : 'success');
    setSuspendTarget(null);
  }

  if (selectedUser) {
    return <UserDetail user={selectedUser} onBack={() => setSelectedUser(null)} />;
  }

  return (
    <div>
      {/* ── Live status bar ── */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12,
        padding: '8px 14px', borderRadius: 10,
        background: isLive ? 'rgba(34,197,94,0.08)' : 'rgba(239,68,68,0.07)',
        border: `1px solid ${isLive ? 'rgba(34,197,94,0.25)' : 'rgba(239,68,68,0.2)'}`,
      }}>
        <span style={{
          width: 9, height: 9, borderRadius: '50%', flexShrink: 0,
          background: isLive ? '#22c55e' : '#ef4444',
          boxShadow: isLive ? '0 0 0 3px rgba(34,197,94,0.25)' : 'none',
          animation: isLive ? 'liveGlow 1.5s infinite' : 'none',
        }} />
        <span style={{ fontSize: 12, fontWeight: 700, color: isLive ? '#16a34a' : '#dc2626' }}>
          {isLive ? '● LIVE — auto-syncing every 3 seconds + real-time push' : '○ Connecting to real-time…'}
        </span>
        {newUserCount > 0 && (
          <span style={{
            marginLeft: 'auto', fontSize: 11, fontWeight: 800,
            background: '#e8741f', color: '#fff', borderRadius: 20, padding: '2px 10px',
          }}>
            +{newUserCount} new since open
          </span>
        )}
        <button
          onClick={() => { fetchData(); setNewUserCount(0); }}
          style={{
            marginLeft: newUserCount > 0 ? 6 : 'auto',
            fontSize: 11, fontWeight: 700, background: 'transparent',
            border: '1px solid currentColor', borderRadius: 8,
            padding: '3px 10px', cursor: 'pointer', color: 'var(--ink-soft)',
          }}
        >
          ↻ Refresh Now
        </button>
      </div>

      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search by name or email…" value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
        <div style={{ fontSize: 12, color: 'var(--ink-soft)', marginLeft: 'auto', paddingRight: 4 }}>
            {total} traveller{total !== 1 ? 's' : ''}
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>User</th><th>Role</th><th>Joined</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={5}><Skeleton rows={8} cols={5} /></td></tr>
                : error ? <tr><td colSpan={5}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={5}>
                    <div className="empty-state">
                      <div className="empty-state-icon">👤</div>
                      <div className="empty-state-title">No travellers found</div>
                      <div style={{ fontSize: 13, color: 'var(--ink-soft)', marginTop: 4 }}>
                        When someone signs up on the mobile app, they will appear here instantly.
                      </div>
                    </div>
                  </td></tr>
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
                    <td>
                      <span className="badge badge-grey">Traveller</span>
                    </td>
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

      <style>{`
        @keyframes liveGlow {
          0%, 100% { opacity: 1; box-shadow: 0 0 0 3px rgba(34,197,94,0.25); }
          50% { opacity: 0.5; box-shadow: 0 0 0 6px rgba(34,197,94,0.08); }
        }
      `}</style>
    </div>
  );
}
