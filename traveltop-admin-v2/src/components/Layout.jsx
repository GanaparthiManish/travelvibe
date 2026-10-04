import React, { useState, useEffect } from 'react';
import Sidebar from './Sidebar';
import { supabase } from '../lib/supabase';

// Lazy-loaded pages
import Dashboard from '../pages/Dashboard';
import Destinations from '../pages/Destinations';
import Agents from '../pages/Agents';
import Users from '../pages/Users';
import Bookings from '../pages/Bookings';
import Products from '../pages/Products';
import Orders from '../pages/Orders';
import Payouts from '../pages/Payouts';
import Reviews from '../pages/Reviews';
import Announcements from '../pages/Announcements';
import AdminUsers from '../pages/AdminUsers';
import SupportTickets from '../pages/SupportTickets';
import Banners from '../pages/Banners';
import Coupons from '../pages/Coupons';
import Policies from '../pages/Policies';
import Settings from '../pages/Settings';
import SOSIncidents from '../pages/SOSIncidents';

const PAGE_TITLES = {
  dashboard: 'Dashboard',
  sos_incidents: '🚨 Emergency SOS Incidents',
  destinations: 'Destinations',
  agents: 'Agents',
  users: 'Users (Travellers)',
  bookings: 'Bookings',
  products: 'Products (Shop)',
  orders: 'Orders',
  payouts: 'Payouts',
  reviews: 'Reviews Moderation',
  banners: 'Promotional Banners',
  coupons: 'Discount Coupons',
  support: 'Support Tickets',
  announcements: 'Announcements',
  policies: 'Terms & Policies Manager',
  settings: 'Application Settings',
  admins: 'Admin Users',
};

export default function Layout() {
  const [activePage, setActivePage] = useState('dashboard');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [realtimeConnected, setRealtimeConnected] = useState(false);

  useEffect(() => {
    // Monitor realtime connection status
    const channel = supabase.channel('__heartbeat__')
      .on('system', {}, (payload) => {
        if (payload.extension === 'postgres_changes') setRealtimeConnected(true);
      })
      .subscribe((status) => {
        setRealtimeConnected(status === 'SUBSCRIBED');
      });

    return () => supabase.removeChannel(channel);
  }, []);

  function renderPage() {
    switch (activePage) {
      case 'dashboard': return <Dashboard />;
      case 'sos_incidents': return <SOSIncidents />;
      case 'destinations': return <Destinations />;
      case 'agents': return <Agents />;
      case 'users': return <Users />;
      case 'bookings': return <Bookings />;
      case 'products': return <Products />;
      case 'orders': return <Orders />;
      case 'payouts': return <Payouts />;
      case 'reviews': return <Reviews />;
      case 'banners': return <Banners />;
      case 'coupons': return <Coupons />;
      case 'support': return <SupportTickets />;
      case 'announcements': return <Announcements />;
      case 'policies': return <Policies />;
      case 'settings': return <Settings />;
      case 'admins': return <AdminUsers />;
      default: return <Dashboard />;
    }
  }

  return (
    <div className="layout">
      {sidebarOpen && (
        <div className="mobile-sidebar-overlay" onClick={() => setSidebarOpen(false)} />
      )}
      <Sidebar
        activePage={activePage}
        onNavigate={(page) => {
          setActivePage(page);
          setSidebarOpen(false);
        }}
        realtimeConnected={realtimeConnected}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />
      <div className="main">
        <div className="topbar">
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <button
              className="mobile-menu-btn"
              onClick={() => setSidebarOpen(!sidebarOpen)}
              aria-label="Toggle menu"
            >
              ☰
            </button>
            <h2 className="topbar-title">{PAGE_TITLES[activePage]}</h2>
          </div>
          <div className="topbar-right">
            <div className={`realtime-badge${realtimeConnected ? '' : ' offline'}`} style={{ fontSize: 11 }}>
              <span className={`status-dot${realtimeConnected ? '' : ' offline'}`} />
              <span className="badge-text">{realtimeConnected ? 'Live Sync Active' : 'Connecting…'}</span>
            </div>
          </div>
        </div>
        <div className="content-area">
          <div className="content-inner">
            {renderPage()}
          </div>
        </div>
      </div>
    </div>
  );
}
