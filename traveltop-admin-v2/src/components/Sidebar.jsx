import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { supabase } from '../lib/supabase';

const NAV_ITEMS = [
  { id: 'dashboard', icon: '◾', label: 'Dashboard' },
  { id: 'sos_incidents', icon: '🚨', label: 'SOS Incidents', urgent: true },
  { id: 'destinations', icon: '📍', label: 'Destinations' },
  { id: 'agents', icon: '🧑‍💼', label: 'Agents' },
  { id: 'users', icon: '👥', label: 'Users' },
  { id: 'bookings', icon: '📅', label: 'Bookings' },
  { id: 'products', icon: '🛍️', label: 'Products' },
  { id: 'orders', icon: '📦', label: 'Orders' },
  { id: 'payouts', icon: '💸', label: 'Payouts' },
  { id: 'reviews', icon: '⭐', label: 'Reviews' },
  { id: 'banners', icon: '🎨', label: 'Banners' },
  { id: 'coupons', icon: '🎟️', label: 'Coupons' },
  { id: 'support', icon: '🎧', label: 'Support Tickets' },
  { id: 'announcements', icon: '📢', label: 'Announcements' },
  { id: 'policies', icon: '📜', label: 'Terms & Policies' },
  { id: 'settings', icon: '⚙️', label: 'Settings' },
  { id: 'admins', icon: '🔑', label: 'Admin Users', superAdminOnly: true },
];

export default function Sidebar({ activePage, onNavigate, realtimeConnected, isOpen, onClose }) {
  const { adminUser, isSuperAdmin, signOut } = useAuth();
  const [openSosCount, setOpenSosCount] = useState(0);

  useEffect(() => {
    async function fetchOpenSos() {
      try {
        const { count } = await supabase
          .from('sos_incidents')
          .select('id', { count: 'exact', head: true })
          .eq('status', 'open');
        setOpenSosCount(count || 0);
      } catch (_) {}
    }
    fetchOpenSos();

    const ch = supabase.channel('sidebar_sos_count')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'sos_incidents' }, fetchOpenSos)
      .on('broadcast', { event: 'sos_triggered' }, fetchOpenSos)
      .subscribe();

    return () => supabase.removeChannel(ch);
  }, []);

  const initials = adminUser?.full_name
    ? adminUser.full_name.split(' ').map(n => n[0]).join('').slice(0, 2).toUpperCase()
    : 'AD';

  const visibleItems = isSuperAdmin
    ? NAV_ITEMS
    : NAV_ITEMS.filter(n => !n.superAdminOnly);

  return (
    <aside className={`sidebar${isOpen ? ' mobile-open' : ''}`}>
      {/* Brand */}
      <div className="sidebar-brand">
        <div className="sidebar-brand-inner" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 10,
              background: 'linear-gradient(135deg, #FF7300 0%, #8B5CF6 100%)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 3px 10px rgba(139, 92, 246, 0.3)',
              flexShrink: 0,
            }}
          >
            <div
              style={{
                width: 20,
                height: 20,
                borderRadius: '50%',
                border: '2px solid #FFFFFF',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ transform: 'rotate(-25deg)' }}>
                <polygon points="12 2 19 21 12 17 5 21 12 2"></polygon>
              </svg>
            </div>
          </div>
          <div className="sidebar-brand-text">
            <h1 style={{ fontSize: '18px', fontWeight: 900, margin: 0, letterSpacing: '-0.02em', lineHeight: 1.1 }}>
              <span style={{ color: '#FF7300' }}>Travel</span>
              <span style={{ color: '#8B5CF6', fontStyle: 'italic' }}>Vibe</span>
            </h1>
            <p style={{ margin: 0, fontSize: 10, color: 'var(--ink-soft)', fontWeight: 600 }}>Admin Console</p>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="sidebar-nav">
        {visibleItems.map(item => (
          <button
            key={item.id}
            className={`nav-item${activePage === item.id ? ' active' : ''}`}
            onClick={() => onNavigate(item.id)}
            style={item.urgent && openSosCount > 0 ? { borderLeft: '3px solid #dc2626', background: '#fef2f2' } : {}}
          >
            <span className="nav-icon">{item.icon}</span>
            <span style={{ flex: 1, textAlign: 'left' }}>{item.label}</span>
            {item.id === 'sos_incidents' && openSosCount > 0 && (
              <span style={{
                background: '#dc2626',
                color: '#fff',
                fontSize: 10,
                fontWeight: 900,
                padding: '1px 6px',
                borderRadius: 10,
                boxShadow: '0 2px 6px rgba(220, 38, 38, 0.4)',
                animation: 'pulse 1.5s infinite'
              }}>
                {openSosCount}
              </span>
            )}
          </button>
        ))}
      </nav>

      {/* Footer */}
      <div className="sidebar-footer">
        {/* Realtime badge */}
        <div className={`realtime-badge${realtimeConnected ? '' : ' offline'}`}>
          <span className={`status-dot${realtimeConnected ? '' : ' offline'}`} />
          {realtimeConnected ? 'Live Sync Active' : 'Disconnected'}
        </div>

        {/* Admin info */}
        {adminUser && (
          <div className="sidebar-admin-info">
            <div className="sidebar-admin-avatar">{initials}</div>
            <div>
              <div className="sidebar-admin-name">{adminUser.full_name || 'Admin'}</div>
              <div className="sidebar-admin-role">{adminUser.role?.replace('_', ' ')}</div>
            </div>
          </div>
        )}

        {/* Sign out */}
        <button className="sidebar-signout" onClick={signOut}>
          <span>↪</span> Sign out
        </button>
      </div>
    </aside>
  );
}
