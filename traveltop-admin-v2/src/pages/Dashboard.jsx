import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import StatusBadge from '../components/StatusBadge';

const INR = v => `₹${Number(v || 0).toLocaleString('en-IN')}`;

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [bookingChart, setBookingChart] = useState([]);
  const [revenueChart, setRevenueChart] = useState([]);
  const [topDests, setTopDests] = useState([]);
  const [topAgents, setTopAgents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetchAll = useCallback(async () => {
    try {
      setError(null);

      const [
        { count: userCount },
        { count: agentCount },
        { count: bookingCount },
        { data: revenueData },
        { data: bookingsRaw },
        { data: destData },
        { data: agentData },
      ] = await Promise.all([
        supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'traveller'),
        supabase.from('profiles').select('*', { count: 'exact', head: true }).eq('role', 'agent'),
        supabase.from('bookings').select('*', { count: 'exact', head: true }),
        supabase.from('bookings').select('total_price').eq('status', 'completed'),
        supabase.from('bookings').select('created_at, total_price, status').order('created_at'),
        supabase.from('destinations').select('id, name, country').limit(5),
        supabase.from('agent_details').select('id, rating_avg, review_count, profiles(full_name, photo_url)').order('rating_avg', { ascending: false }).limit(5),
      ]);

      const totalRevenue = (revenueData || []).reduce((s, b) => s + (b.total_price || 0), 0);

      setStats({ userCount: userCount || 0, agentCount: agentCount || 0, bookingCount: bookingCount || 0, totalRevenue });

      // Build 6-month chart data
      const months = [];
      for (let i = 5; i >= 0; i--) {
        const d = new Date();
        d.setMonth(d.getMonth() - i);
        months.push({
          label: d.toLocaleString('default', { month: 'short' }),
          year: d.getFullYear(),
          month: d.getMonth(),
        });
      }

      const bookingsByMonth = {};
      const revenueByMonth = {};
      months.forEach(m => { bookingsByMonth[m.label] = 0; revenueByMonth[m.label] = 0; });

      (bookingsRaw || []).forEach(b => {
        const d = new Date(b.created_at);
        const label = d.toLocaleString('default', { month: 'short' });
        const m = months.find(mo => mo.label === label && mo.year === d.getFullYear());
        if (m) {
          bookingsByMonth[m.label] = (bookingsByMonth[m.label] || 0) + 1;
          if (b.status === 'completed') revenueByMonth[m.label] = (revenueByMonth[m.label] || 0) + (b.total_price || 0);
        }
      });

      setBookingChart(months.map(m => ({ month: m.label, bookings: bookingsByMonth[m.label] || 0 })));
      setRevenueChart(months.map(m => ({ month: m.label, revenue: revenueByMonth[m.label] || 0 })));

      // Top destinations — by booking count
      const destBookings = {};
      (bookingsRaw || []).forEach(b => {
        if (b.destination) destBookings[b.destination] = (destBookings[b.destination] || 0) + 1;
      });
      const sorted = Object.entries(destBookings).sort((a, b) => b[1] - a[1]).slice(0, 5);
      setTopDests(sorted.map(([name, count]) => ({ name, count })));

      setTopAgents(agentData || []);
      setLoading(false);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAll();

    // Real-time subscriptions for stat updates
    const channel = supabase.channel('dashboard_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, fetchAll)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, fetchAll)
      .subscribe();

    return () => supabase.removeChannel(channel);
  }, [fetchAll]);

  if (error) return <ErrorState message={error} onRetry={fetchAll} />;

  const STAT_CARDS = [
    { label: 'Total Users', value: stats?.userCount, icon: '👥', color: '#dbeafe', iconColor: '#1d4ed8' },
    { label: 'Total Agents', value: stats?.agentCount, icon: '🧑‍💼', color: '#dcfce7', iconColor: '#16a34a' },
    { label: 'Total Bookings', value: stats?.bookingCount, icon: '📅', color: '#fef3c7', iconColor: '#d97706' },
    { label: 'Total Revenue', value: stats ? INR(stats.totalRevenue) : null, icon: '💰', color: '#fce7f3', iconColor: '#db2777' },
  ];

  return (
    <div>
      {/* Stat Cards */}
      <div className="stat-grid">
        {STAT_CARDS.map((s, i) => (
          <div className="stat-card" key={i}>
            <div className="stat-icon-wrap" style={{ background: s.color }}>
              <span style={{ fontSize: 18 }}>{s.icon}</span>
            </div>
            {loading
              ? <div className="skeleton skeleton-text" style={{ width: 70, height: 28, marginBottom: 4 }} />
              : <div className="stat-value">{s.value ?? '—'}</div>
            }
            <div className="stat-label">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Charts */}
      <div className="charts-grid">
        <div className="chart-card">
          <div className="chart-title">Bookings — Last 6 Months</div>
          {loading ? <div className="skeleton" style={{ height: 180 }} /> : (
            <div style={{ width: '100%', height: 180 }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={bookingChart} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EBEBEB" vertical={false} />
                  <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#666' }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: '#666' }} axisLine={false} tickLine={false} allowDecimals={false} width={25} />
                  <Tooltip contentStyle={{ border: '1px solid #EBEBEB', borderRadius: 8, fontSize: 12 }} />
                  <Bar dataKey="bookings" fill="#E8483A" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>

        <div className="chart-card">
          <div className="chart-title">Revenue — Last 6 Months (₹)</div>
          {loading ? <div className="skeleton" style={{ height: 180 }} /> : (
            <div style={{ width: '100%', height: 180 }}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={revenueChart} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EBEBEB" vertical={false} />
                  <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#666' }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: '#666' }} axisLine={false} tickLine={false} width={30}
                    tickFormatter={v => v >= 1000 ? `${(v / 1000).toFixed(0)}k` : v} />
                  <Tooltip contentStyle={{ border: '1px solid #EBEBEB', borderRadius: 8, fontSize: 12 }}
                    formatter={v => [INR(v), 'Revenue']} />
                  <Line dataKey="revenue" stroke="#E8483A" strokeWidth={2} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          )}
        </div>
      </div>

      {/* Bottom tables */}
      <div className="dashboard-bottom-grid">
        {/* Top Destinations */}
        <div className="card">
          <div className="card-header">
            <div className="card-title">Top Destinations</div>
            <span className="cell-muted">by bookings</span>
          </div>
          <div className="table-wrap">
            <table>
              <thead><tr>
                <th>#</th><th>Destination</th><th>Bookings</th>
              </tr></thead>
              <tbody>
                {loading ? <tr><td colSpan={3}><Skeleton rows={4} cols={3} /></td></tr>
                  : topDests.length === 0
                    ? <tr><td colSpan={3} style={{ textAlign: 'center', padding: 24, color: 'var(--ink-soft)' }}>No booking data yet</td></tr>
                    : topDests.map((d, i) => (
                      <tr key={d.name}>
                        <td style={{ color: 'var(--ink-lighter)', fontWeight: 700, width: 32 }}>{i + 1}</td>
                        <td><span style={{ fontWeight: 600 }}>{d.name}</span></td>
                        <td><span className="badge badge-blue">{d.count}</span></td>
                      </tr>
                    ))
                }
              </tbody>
            </table>
          </div>
        </div>

        {/* Top Agents */}
        <div className="card">
          <div className="card-header">
            <div className="card-title">Top Agents</div>
            <span className="cell-muted">by rating</span>
          </div>
          <div className="table-wrap">
            <table>
              <thead><tr>
                <th>#</th><th>Agent</th><th>Rating</th>
              </tr></thead>
              <tbody>
                {loading ? <tr><td colSpan={3}><Skeleton rows={4} cols={3} /></td></tr>
                  : topAgents.length === 0
                    ? <tr><td colSpan={3} style={{ textAlign: 'center', padding: 24, color: 'var(--ink-soft)' }}>No agents yet</td></tr>
                    : topAgents.map((a, i) => (
                      <tr key={a.id}>
                        <td style={{ color: 'var(--ink-lighter)', fontWeight: 700, width: 32 }}>{i + 1}</td>
                        <td><span style={{ fontWeight: 600 }}>{a.profiles?.full_name || '—'}</span></td>
                        <td>
                          <span style={{ display: 'flex', alignItems: 'center', gap: 4, fontWeight: 700, fontSize: 13 }}>
                            ⭐ {a.rating_avg ? Number(a.rating_avg).toFixed(1) : '—'}
                          </span>
                        </td>
                      </tr>
                    ))
                }
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
