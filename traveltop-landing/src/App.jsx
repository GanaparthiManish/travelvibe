import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { WishlistProvider } from './context/WishlistContext';
import { LanguageProvider } from './context/LanguageContext';

import Navbar from './components/Navbar';
import Footer from './components/Footer';

import LandingPage from './pages/LandingPage';
import Login from './pages/Login';
import Signup from './pages/Signup';
import Home from './pages/Home';
import DestinationDetail from './pages/DestinationDetail';
import AgentListing from './pages/AgentListing';
import AgentProfile from './pages/AgentProfile';
import BookingFlow from './pages/BookingFlow';
import MyTrips from './pages/MyTrips';
import Shop from './pages/Shop';
import ProductDetail from './pages/ProductDetail';
import MyOrders from './pages/MyOrders';
import Wishlist from './pages/Wishlist';
import Profile from './pages/Profile';
import Chat from './pages/Chat';

import AgentLogin from './pages/agent/AgentLogin';
import AgentSignup from './pages/agent/AgentSignup';
import AgentPending from './pages/agent/AgentPending';
import AgentDashboard from './pages/agent/AgentDashboard';
import AgentAvailability from './pages/agent/AgentAvailability';
import AgentEarnings from './pages/agent/AgentEarnings';
import AgentProfileEdit from './pages/agent/AgentProfileEdit';
import AgentPayoutMethod from './pages/agent/AgentPayoutMethod';

import HelpSupport from './pages/HelpSupport';
import Terms from './pages/Terms';
import PrivacyPolicy from './pages/PrivacyPolicy';

// Agent Guard: Only authenticated agents can access agent routes
function AgentRoute({ children }) {
  const { user, isAgent, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-purple-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/agent/login" replace />;
  }

  if (!isAgent) {
    return <Navigate to="/app" replace />;
  }

  return children;
}

// Traveller Guard: Agents are kept inside the Agent app and redirected to Agent Dashboard
function TravellerRoute({ children }) {
  const { isAgent, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-8 h-8 border-4 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (isAgent) {
    return <Navigate to="/agent/dashboard" replace />;
  }

  return children;
}

function Layout({ children }) {
  return (
    <div className="flex flex-col min-h-screen font-sans bg-[#F7F6FB] text-[#222222]">
      <Navbar />
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <WishlistProvider>
        <LanguageProvider>
          <BrowserRouter>
            <Layout>
              <Routes>
                {/* PUBLIC LANDING & INFO */}
                <Route path="/" element={<TravellerRoute><LandingPage /></TravellerRoute>} />
                <Route path="/help" element={<HelpSupport />} />
                <Route path="/terms" element={<Terms />} />
                <Route path="/privacy" element={<PrivacyPolicy />} />

                {/* AUTH */}
                <Route path="/login" element={<Login />} />
                <Route path="/signup" element={<Signup />} />
                <Route path="/agent/login" element={<AgentLogin />} />
                <Route path="/agent/signup" element={<AgentSignup />} />

                {/* TRAVELLER APP ROUTES (STRICTLY FOR TRAVELLERS / VISITORS) */}
                <Route path="/app" element={<TravellerRoute><Home /></TravellerRoute>} />
                <Route path="/destinations/:id" element={<TravellerRoute><DestinationDetail /></TravellerRoute>} />
                <Route path="/agents" element={<TravellerRoute><AgentListing /></TravellerRoute>} />
                <Route path="/agents/:id" element={<TravellerRoute><AgentProfile /></TravellerRoute>} />
                <Route path="/book/:agentId" element={<TravellerRoute><BookingFlow /></TravellerRoute>} />
                <Route path="/my-trips" element={<TravellerRoute><MyTrips /></TravellerRoute>} />
                <Route path="/shop" element={<TravellerRoute><Shop /></TravellerRoute>} />
                <Route path="/shop/:productId" element={<TravellerRoute><ProductDetail /></TravellerRoute>} />
                <Route path="/my-orders" element={<TravellerRoute><MyOrders /></TravellerRoute>} />
                <Route path="/wishlist" element={<TravellerRoute><Wishlist /></TravellerRoute>} />
                <Route path="/profile" element={<Profile />} />
                <Route path="/chat/:bookingId" element={<Chat />} />

                {/* AGENT APP ROUTES (STRICTLY FOR AGENTS) */}
                <Route path="/agent/pending" element={<AgentPending />} />
                <Route path="/agent/dashboard" element={<AgentRoute><AgentDashboard /></AgentRoute>} />
                <Route path="/agent/profile" element={<AgentRoute><AgentProfileEdit /></AgentRoute>} />
                <Route path="/agent/bookings" element={<AgentRoute><AgentDashboard /></AgentRoute>} />
                <Route path="/agent/availability" element={<AgentRoute><AgentAvailability /></AgentRoute>} />
                <Route path="/agent/earnings" element={<AgentRoute><AgentEarnings /></AgentRoute>} />
                <Route path="/agent/payout-method" element={<AgentRoute><AgentPayoutMethod /></AgentRoute>} />
                <Route path="/agent/chat/:bookingId" element={<AgentRoute><Chat /></AgentRoute>} />
              </Routes>
            </Layout>
          </BrowserRouter>
        </LanguageProvider>
      </WishlistProvider>
    </AuthProvider>
  );
}
