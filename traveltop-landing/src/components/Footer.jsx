import React from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Compass, Shield, ShieldCheck, Mail, Phone, MapPin, Calendar, Clock, DollarSign } from 'lucide-react';

export default function Footer() {
  const { isAgent } = useAuth();

  if (isAgent) {
    return (
      <footer className="bg-[#1A1825] text-white pt-12 pb-10 border-t border-purple-950/60">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 pb-10 border-b border-gray-800">
            
            {/* BRAND */}
            <div className="space-y-3">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 bg-white rounded-xl flex items-center justify-center p-1">
                  <img src="/logo.png" alt="TravelVibe Logo" className="w-full h-full object-contain" onError={(e) => {
                    e.target.style.display = 'none';
                    if (e.target.nextSibling) e.target.nextSibling.style.display = 'block';
                  }} />
                  <Compass className="hidden w-5 h-5 text-[#8B61F1]" />
                </div>
                <div className="text-lg font-extrabold tracking-tight flex items-center gap-1.5">
                  <span className="text-[#E8741F]">Travel</span>
                  <span className="text-[#8B61F1] italic">Vibe</span>
                  <span className="px-2 py-0.5 bg-purple-900/80 text-purple-300 text-[10px] font-black rounded-md uppercase">
                    Agent Portal
                  </span>
                </div>
              </div>
              <p className="text-gray-400 text-xs leading-relaxed max-w-sm">
                Official guide partner console for verified local travel specialists. Manage traveller bookings, calendar schedules, and payout requests securely.
              </p>
            </div>

            {/* AGENT CONSOLE LINKS */}
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-purple-300 mb-3">Agent Management</h4>
              <ul className="space-y-2 text-xs font-medium text-gray-400">
                <li><Link to="/agent/dashboard" className="hover:text-purple-300 flex items-center gap-2"><Calendar className="w-3.5 h-3.5" /> Bookings & Requests</Link></li>
                <li><Link to="/agent/availability" className="hover:text-purple-300 flex items-center gap-2"><Clock className="w-3.5 h-3.5" /> Availability Calendar</Link></li>
                <li><Link to="/agent/earnings" className="hover:text-purple-300 flex items-center gap-2"><DollarSign className="w-3.5 h-3.5" /> Earnings & Payouts</Link></li>
              </ul>
            </div>

            {/* AGENT SUPPORT */}
            <div>
              <h4 className="text-xs font-bold uppercase tracking-wider text-purple-300 mb-3">Partner Assistance</h4>
              <div className="space-y-2 text-xs text-gray-400">
                <a href="mailto:support@travelvibe.com" className="flex items-center gap-2 hover:text-purple-300">
                  <Mail className="w-3.5 h-3.5 text-[#8B61F1]" /> partner-support@travelvibe.com
                </a>
                <div className="flex items-center gap-2">
                  <Phone className="w-3.5 h-3.5 text-[#8B61F1]" /> +91 98765 43210 (Partner Helpline)
                </div>
              </div>
            </div>

          </div>

          <div className="pt-6 flex flex-col md:flex-row items-center justify-between gap-4 text-[11px] font-semibold text-gray-500">
            <p>© {new Date().getFullYear()} TravelVibe Technologies Pvt Ltd. All rights reserved.</p>
            <div className="flex items-center gap-5">
              <Link to="/privacy" className="hover:text-gray-400">Privacy Policy</Link>
              <Link to="/terms" className="hover:text-gray-400">Agent Terms of Service</Link>
            </div>
          </div>
        </div>
      </footer>
    );
  }

  return (
    <footer className="bg-[#222222] text-white pt-16 pb-12 border-t border-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 pb-12 border-b border-gray-800">
          
          {/* BRAND COLUMN */}
          <div className="space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center p-1">
                <img src="/logo.png" alt="TravelVibe Logo" className="w-full h-full object-contain" onError={(e) => {
                  e.target.style.display = 'none';
                  if (e.target.nextSibling) e.target.nextSibling.style.display = 'block';
                }} />
                <Compass className="hidden w-6 h-6 text-[#E8741F]" />
              </div>
              <div className="text-xl font-extrabold tracking-tight">
                <span className="text-[#E8741F]">Travel</span>
                <span className="text-[#8B61F1] italic">Vibe</span>
              </div>
            </div>
            <p className="text-gray-400 text-sm leading-relaxed">
              Connect with verified local experts for authentic, safe, and personalized travel experiences across India.
            </p>
            <div className="flex items-center gap-2 text-xs font-semibold text-emerald-400 bg-emerald-950/60 border border-emerald-800/50 px-3 py-1.5 rounded-lg w-fit">
              <Shield className="w-4 h-4" /> 100% Verified Local Guides
            </div>
          </div>

          {/* EXPLORE */}
          <div>
            <h4 className="text-sm font-bold uppercase tracking-wider text-gray-300 mb-4">Explore</h4>
            <ul className="space-y-2.5 text-sm font-medium text-gray-400">
              <li><Link to="/app" className="hover:text-[#E8741F] transition-colors">Popular Destinations</Link></li>
              <li><Link to="/agents" className="hover:text-[#E8741F] transition-colors">Find Local Guides</Link></li>
              <li><Link to="/shop" className="hover:text-[#E8741F] transition-colors">Travel Gear Shop</Link></li>
            </ul>
          </div>

          {/* TRAVELLER PORTAL */}
          <div>
            <h4 className="text-sm font-bold uppercase tracking-wider text-gray-300 mb-4">My Account</h4>
            <ul className="space-y-2.5 text-sm font-medium text-gray-400">
              <li><Link to="/my-trips" className="hover:text-white transition-colors">My Bookings</Link></li>
              <li><Link to="/my-orders" className="hover:text-white transition-colors">Order Tracking</Link></li>
              <li><Link to="/wishlist" className="hover:text-white transition-colors">Saved Wishlist</Link></li>
            </ul>
          </div>

          {/* CONTACT & SUPPORT */}
          <div>
            <h4 className="text-sm font-bold uppercase tracking-wider text-gray-300 mb-4">Support & Trust</h4>
            <div className="space-y-3 text-sm text-gray-400">
              <Link to="/help" className="flex items-center gap-2 hover:text-[#E8741F] transition-colors">
                <Mail className="w-4 h-4 text-[#E8741F]" /> Help & Support Center
              </Link>
              <div className="flex items-center gap-2">
                <Phone className="w-4 h-4 text-[#8B61F1]" /> +91 98765 43210
              </div>
              <div className="flex items-center gap-2">
                <MapPin className="w-4 h-4 text-emerald-400" /> Bengaluru, Karnataka, India
              </div>
            </div>
          </div>

        </div>

        {/* BOTTOM COPYRIGHT */}
        <div className="pt-8 flex flex-col md:flex-row items-center justify-between gap-4 text-xs font-semibold text-gray-500">
          <p>© {new Date().getFullYear()} TravelVibe Technologies Pvt Ltd. All rights reserved.</p>
          <div className="flex items-center gap-6">
            <Link to="/privacy" className="hover:text-gray-300 transition-colors">Privacy Policy</Link>
            <Link to="/terms" className="hover:text-gray-300 transition-colors">Terms of Service</Link>
            <Link to="/help" className="hover:text-gray-300 transition-colors">Safety Guidelines</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
