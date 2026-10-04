import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useLanguage } from '../context/LanguageContext';
import { Compass, ShoppingBag, Heart, Calendar, User, LogOut, Menu, X, Shield, ShieldCheck, DollarSign, Clock, Globe } from 'lucide-react';

export default function Navbar() {
  const { user, profile, isAgent, isVerifiedAgent, signOut } = useAuth();
  const { language, setLanguage, t, supportedLanguages } = useLanguage();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [userDropdownOpen, setUserDropdownOpen] = useState(false);
  const [langDropdownOpen, setLangDropdownOpen] = useState(false);

  const isActive = (path) => location.pathname === path;

  const handleLogout = async () => {
    await signOut();
    if (isAgent) {
      navigate('/agent/login');
    } else {
      navigate('/login');
    }
  };

  return (
    <header className="sticky top-0 z-50 bg-white/95 backdrop-blur-md border-b border-gray-200/80 shadow-xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between gap-4">
        
        {/* LOGO + BRAND */}
        <Link
          to={isAgent ? '/agent/dashboard' : user ? '/app' : '/'}
          className="flex items-center gap-3 group shrink-0"
        >
          <div className="w-11 h-11 bg-white rounded-2xl shadow-sm border border-gray-200 flex items-center justify-center overflow-hidden p-1.5 transition-transform group-hover:scale-105">
            <img
              src="/logo.png"
              alt="TravelVibe Logo"
              className="w-full h-full object-contain"
              onError={(e) => {
                e.target.style.display = 'none';
                if (e.target.nextSibling) e.target.nextSibling.style.display = 'flex';
              }}
            />
            <div className="hidden text-[#E8741F] items-center justify-center">
              <Compass className="w-6 h-6" />
            </div>
          </div>
          <div className="flex flex-col">
            <div className="text-xl sm:text-2xl font-black tracking-tight leading-none flex items-center gap-1">
              <span className="text-[#E8741F]">Travel</span>
              <span className="text-[#8B61F1] italic">Vibe</span>
              {isAgent && (
                <span className="ml-1.5 px-2 py-0.5 bg-purple-100 text-[#8B61F1] text-[10px] font-extrabold rounded-md uppercase tracking-wider">
                  Agent
                </span>
              )}
            </div>
            <span className="text-[10px] font-bold text-gray-400 tracking-wider uppercase mt-1 hidden sm:inline">
              {isAgent ? 'Local Guide Partner Portal' : 'Local Guides & Experiences'}
            </span>
          </div>
        </Link>

        {/* DESKTOP NAVIGATION: STRICTLY SPLIT BY ROLE */}
        {isAgent ? (
          /* ================= AGENT DESKTOP NAV ================= */
          <nav className="hidden lg:flex items-center gap-2 xl:gap-3">
            <Link
              to="/agent/dashboard"
              className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl flex items-center gap-2 ${
                isActive('/agent/dashboard') || isActive('/agent/bookings')
                  ? 'text-[#8B61F1] bg-purple-50 shadow-2xs font-black'
                  : 'text-gray-700 hover:text-[#8B61F1] hover:bg-purple-50/50'
              }`}
            >
              <Calendar className="w-4 h-4 text-[#8B61F1]" />
              Bookings & Requests
            </Link>

            <Link
              to="/agent/availability"
              className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl flex items-center gap-2 ${
                isActive('/agent/availability')
                  ? 'text-[#8B61F1] bg-purple-50 shadow-2xs font-black'
                  : 'text-gray-700 hover:text-[#8B61F1] hover:bg-purple-50/50'
              }`}
            >
              <Clock className="w-4 h-4 text-[#8B61F1]" />
              Availability Calendar
            </Link>

            <Link
              to="/agent/earnings"
              className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl flex items-center gap-2 ${
                isActive('/agent/earnings')
                  ? 'text-[#8B61F1] bg-purple-50 shadow-2xs font-black'
                  : 'text-gray-700 hover:text-[#8B61F1] hover:bg-purple-50/50'
              }`}
            >
              <DollarSign className="w-4 h-4 text-[#8B61F1]" />
              Earnings & Payouts
            </Link>
          </nav>
        ) : (
          /* ================= TRAVELLER / PUBLIC DESKTOP NAV ================= */
          <nav className="hidden lg:flex items-center gap-2 xl:gap-3">
            <Link
              to="/app"
              className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl ${
                isActive('/app') ? 'text-[#E8741F] bg-orange-50/90 shadow-2xs' : 'text-gray-700 hover:text-[#E8741F] hover:bg-gray-100/70'
              }`}
            >
              {t('nav_home', 'Explore')}
            </Link>

            <Link
              to="/agents"
              className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl ${
                isActive('/agents') ? 'text-[#E8741F] bg-orange-50/90 shadow-2xs' : 'text-gray-700 hover:text-[#E8741F] hover:bg-gray-100/70'
              }`}
            >
              {t('nav_guides', 'Guides')}
            </Link>

            <Link
              to="/shop"
              className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl ${
                isActive('/shop') ? 'text-[#E8741F] bg-orange-50/90 shadow-2xs' : 'text-gray-700 hover:text-[#E8741F] hover:bg-gray-100/70'
              }`}
            >
              {t('nav_shop', 'Gear Shop')}
            </Link>

            {user && (
              <>
                <Link
                  to="/my-trips"
                  className={`text-sm font-extrabold transition-all px-3.5 py-2 rounded-xl flex items-center gap-1.5 ${
                    isActive('/my-trips') ? 'text-[#8B61F1] bg-purple-50/90 shadow-2xs' : 'text-gray-700 hover:text-[#8B61F1] hover:bg-gray-100/70'
                  }`}
                >
                  <Calendar className="w-4 h-4 text-[#8B61F1]" />
                  {t('nav_trips', 'My Trips')}
                </Link>

                <Link
                  to="/wishlist"
                  className={`p-2.5 rounded-xl text-sm font-bold transition-all ${
                    isActive('/wishlist') ? 'text-rose-600 bg-rose-50' : 'text-gray-600 hover:text-rose-600 hover:bg-gray-100/70'
                  }`}
                  title={t('nav_wishlist', 'Saved')}
                >
                  <Heart className="w-4 h-4" />
                </Link>
              </>
            )}
          </nav>
        )}

        {/* RIGHT ACTION BUTTONS */}
        <div className="hidden md:flex items-center gap-3 shrink-0">
          {/* REGIONAL LANGUAGE SELECTOR DROPDOWN */}
          <div className="relative">
            <button
              onClick={() => setLangDropdownOpen(!langDropdownOpen)}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-gray-200/90 text-xs font-bold text-gray-700 hover:bg-gray-50 hover:border-gray-300 transition-all cursor-pointer bg-white"
              title="Change Language"
            >
              <Globe className="w-3.5 h-3.5 text-[#E8741F]" />
              <span>{supportedLanguages.find((l) => l.code === language)?.native || 'English'}</span>
            </button>

            {langDropdownOpen && (
              <div
                className="absolute right-0 mt-2 w-44 bg-white rounded-2xl shadow-xl border border-gray-100 py-1.5 z-50 animate-in fade-in zoom-in-95 duration-150"
                onMouseLeave={() => setLangDropdownOpen(false)}
              >
                <div className="px-3 py-1.5 border-b border-gray-100">
                  <p className="text-[10px] font-extrabold text-gray-400 uppercase tracking-wider">Select Language</p>
                </div>
                {supportedLanguages.map((l) => (
                  <button
                    key={l.code}
                    onClick={() => {
                      setLanguage(l.code);
                      setLangDropdownOpen(false);
                    }}
                    className={`w-full text-left px-3.5 py-2 text-xs font-bold flex items-center justify-between cursor-pointer transition-colors ${
                      language === l.code
                        ? 'text-[#E8741F] bg-orange-50 font-black'
                        : 'text-gray-700 hover:bg-gray-50'
                    }`}
                  >
                    <span>{l.native}</span>
                    <span className="text-[10px] text-gray-400 font-normal">{l.label}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
          {isAgent ? (
            /* AGENT STATUS & PROFILE */
            <div className="flex items-center gap-3">
              <span className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-black border ${
                isVerifiedAgent
                  ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                  : 'bg-amber-50 text-amber-700 border-amber-200'
              }`}>
                <ShieldCheck className="w-4 h-4" />
                {isVerifiedAgent ? 'Verified Guide' : 'Pending Verification'}
              </span>

              <div className="relative">
                <button
                  onClick={() => setUserDropdownOpen(!userDropdownOpen)}
                  className="flex items-center gap-2.5 p-1.5 pl-3 rounded-full border border-gray-200/80 hover:shadow-md transition-all bg-white cursor-pointer"
                >
                  <span className="text-xs font-bold text-gray-800 max-w-[120px] truncate">
                    {profile?.full_name || user.email}
                  </span>
                  {profile?.photo_url ? (
                    <img src={profile.photo_url} alt="Profile" className="w-8 h-8 rounded-full object-cover" />
                  ) : (
                    <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-[#8B61F1] to-purple-800 text-white flex items-center justify-center font-bold text-xs">
                      {profile?.full_name?.charAt(0) || 'A'}
                    </div>
                  )}
                </button>

                {userDropdownOpen && (
                  <div
                    className="absolute right-0 mt-2 w-60 bg-white rounded-2xl shadow-2xl border border-gray-100 py-2 z-50 space-y-1"
                    onMouseLeave={() => setUserDropdownOpen(false)}
                  >
                    <div className="px-4 py-3 border-b border-gray-100 bg-purple-50/40">
                      <p className="text-[10px] font-extrabold text-purple-600 uppercase tracking-wider">Agent Account</p>
                      <p className="text-xs font-bold text-gray-900 truncate">{user.email}</p>
                    </div>

                    <Link
                      to="/agent/dashboard"
                      onClick={() => setUserDropdownOpen(false)}
                      className="flex items-center gap-3 px-4 py-2.5 text-xs font-bold text-gray-700 hover:bg-purple-50 hover:text-[#8B61F1]"
                    >
                      <Shield className="w-4 h-4 text-[#8B61F1]" /> Agent Console
                    </Link>

                    <div className="border-t border-gray-100 my-1"></div>

                    <button
                      onClick={() => {
                        setUserDropdownOpen(false);
                        handleLogout();
                      }}
                      className="w-full text-left flex items-center gap-3 px-4 py-2.5 text-xs font-bold text-rose-600 hover:bg-rose-50 cursor-pointer"
                    >
                      <LogOut className="w-4 h-4" /> Sign Out
                    </button>
                  </div>
                )}
              </div>
            </div>
          ) : user ? (
            /* TRAVELLER PROFILE */
            <div className="relative">
              <button
                onClick={() => setUserDropdownOpen(!userDropdownOpen)}
                className="flex items-center gap-2.5 p-1.5 pl-3 rounded-full border border-gray-200/80 hover:shadow-md transition-all bg-white cursor-pointer"
              >
                <span className="text-xs font-bold text-gray-800 max-w-[120px] truncate">
                  {profile?.full_name || user.email}
                </span>
                {profile?.photo_url ? (
                  <img src={profile.photo_url} alt="Profile" className="w-8 h-8 rounded-full object-cover" />
                ) : (
                  <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-[#E8741F] to-[#8B61F1] text-white flex items-center justify-center font-bold text-xs">
                    {profile?.full_name?.charAt(0) || user.email?.charAt(0) || 'U'}
                  </div>
                )}
              </button>

              {userDropdownOpen && (
                <div
                  className="absolute right-0 mt-2 w-60 bg-white rounded-2xl shadow-2xl border border-gray-100 py-2 z-50 space-y-1"
                  onMouseLeave={() => setUserDropdownOpen(false)}
                >
                  <div className="px-4 py-3 border-b border-gray-100 bg-gray-50/50">
                    <p className="text-[10px] font-extrabold text-gray-400 uppercase tracking-wider">Signed in as</p>
                    <p className="text-xs font-bold text-gray-900 truncate">{user.email}</p>
                  </div>

                  <Link
                    to="/profile"
                    onClick={() => setUserDropdownOpen(false)}
                    className="flex items-center gap-3 px-4 py-2.5 text-xs font-bold text-gray-700 hover:bg-orange-50 hover:text-[#E8741F]"
                  >
                    <User className="w-4 h-4 text-gray-400" /> Account Settings
                  </Link>

                  <Link
                    to="/my-orders"
                    onClick={() => setUserDropdownOpen(false)}
                    className="flex items-center gap-3 px-4 py-2.5 text-xs font-bold text-gray-700 hover:bg-orange-50 hover:text-[#E8741F]"
                  >
                    <ShoppingBag className="w-4 h-4 text-gray-400" /> My Shop Orders
                  </Link>

                  <div className="border-t border-gray-100 my-1"></div>

                  <button
                    onClick={() => {
                      setUserDropdownOpen(false);
                      handleLogout();
                    }}
                    className="w-full text-left flex items-center gap-3 px-4 py-2.5 text-xs font-bold text-rose-600 hover:bg-rose-50 cursor-pointer"
                  >
                    <LogOut className="w-4 h-4" /> Sign Out
                  </button>
                </div>
              )}
            </div>
          ) : (
            /* LOGGED OUT VISITOR */
            <div className="flex items-center gap-2.5">
              <Link
                to="/agent/login"
                className="px-3 py-2 text-xs font-bold text-[#8B61F1] hover:bg-purple-50 transition-all rounded-xl"
              >
                Guide Partner Login
              </Link>
              <Link
                to="/login"
                className="px-4 py-2 text-xs font-extrabold text-gray-700 hover:text-[#E8741F] transition-all rounded-xl hover:bg-gray-50"
              >
                Log In
              </Link>
              <Link
                to="/signup"
                className="px-5 py-2.5 text-xs font-black text-white bg-gradient-to-r from-[#E8741F] to-[#D66311] rounded-xl shadow-md shadow-orange-500/20 hover:shadow-orange-500/30 hover:scale-105 active:scale-95 transition-all whitespace-nowrap"
              >
                Sign Up
              </Link>
            </div>
          )}
        </div>

        {/* MOBILE TOGGLE BUTTON */}
        <button
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
          className="lg:hidden p-2 rounded-xl text-gray-700 hover:bg-gray-100 transition-colors"
        >
          {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {/* MOBILE MENU: STRICTLY SEPARATED */}
      {mobileMenuOpen && (
        <div className="lg:hidden bg-white border-b border-gray-200 px-6 py-6 space-y-3">
          {isAgent ? (
            /* AGENT MOBILE MENU */
            <div className="space-y-3">
              <div className="pb-3 border-b border-gray-100 flex items-center justify-between">
                <div>
                  <p className="text-xs font-bold text-gray-900">{profile?.full_name || user.email}</p>
                  <p className="text-[10px] font-extrabold text-[#8B61F1] uppercase">Verified Guide Partner</p>
                </div>
                <span className="px-2 py-0.5 bg-purple-100 text-[#8B61F1] text-[10px] font-black rounded-md">Agent App</span>
              </div>
              <Link
                to="/agent/dashboard"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#8B61F1]"
              >
                Bookings & Requests
              </Link>
              <Link
                to="/agent/availability"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#8B61F1]"
              >
                Availability Calendar
              </Link>
              <Link
                to="/agent/earnings"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#8B61F1]"
              >
                Earnings & Payouts
              </Link>
              <div className="pt-3 border-t border-gray-100">
                <p className="text-[10px] font-extrabold uppercase tracking-wider text-gray-400 mb-2">Language / ഭാഷ / भाषा</p>
                <div className="grid grid-cols-3 sm:grid-cols-5 gap-1.5 mb-3">
                  {supportedLanguages.map((l) => (
                    <button
                      key={l.code}
                      onClick={() => setLanguage(l.code)}
                      className={`px-2 py-1.5 rounded-xl text-xs font-bold text-center border cursor-pointer transition-all ${
                        language === l.code
                          ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-xs'
                          : 'bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100'
                      }`}
                    >
                      {l.native}
                    </button>
                  ))}
                </div>
                <button
                  onClick={() => {
                    setMobileMenuOpen(false);
                    handleLogout();
                  }}
                  className="block w-full text-left py-2 text-sm font-bold text-rose-600"
                >
                  {t('nav_logout', 'Sign Out')} of Agent Console
                </button>
              </div>
            </div>
          ) : user ? (
            /* TRAVELLER MOBILE MENU */
            <div className="space-y-3">
              <Link
                to="/app"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#E8741F]"
              >
                {t('nav_home', 'Explore Destinations')}
              </Link>
              <Link
                to="/agents"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#E8741F]"
              >
                {t('nav_guides', 'Local Guides')}
              </Link>
              <Link
                to="/shop"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#E8741F]"
              >
                {t('nav_shop', 'Travel Shop')}
              </Link>
              <Link
                to="/my-trips"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2 text-sm font-bold text-[#8B61F1]"
              >
                {t('nav_trips', 'My Trips')}
              </Link>
              <Link
                to="/wishlist"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2 text-sm font-bold text-rose-600"
              >
                {t('nav_wishlist', 'Saved Wishlist')}
              </Link>
              <Link
                to="/profile"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2 text-sm font-bold text-gray-700"
              >
                {t('nav_account', 'Account Settings')}
              </Link>
              <Link
                to="/my-orders"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2 text-sm font-bold text-gray-700"
              >
                My Shop Orders
              </Link>
              <div className="pt-3 border-t border-gray-100">
                <p className="text-[10px] font-extrabold uppercase tracking-wider text-gray-400 mb-2">Language / ഭാഷ / भाषा</p>
                <div className="grid grid-cols-3 sm:grid-cols-5 gap-1.5 mb-3">
                  {supportedLanguages.map((l) => (
                    <button
                      key={l.code}
                      onClick={() => setLanguage(l.code)}
                      className={`px-2 py-1.5 rounded-xl text-xs font-bold text-center border cursor-pointer transition-all ${
                        language === l.code
                          ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-xs'
                          : 'bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100'
                      }`}
                    >
                      {l.native}
                    </button>
                  ))}
                </div>
                <button
                  onClick={() => {
                    setMobileMenuOpen(false);
                    handleLogout();
                  }}
                  className="block w-full text-left py-2 text-sm font-bold text-rose-600 cursor-pointer"
                >
                  {t('nav_logout', 'Sign Out')}
                </button>
              </div>
            </div>
          ) : (
            /* VISITOR MOBILE MENU */
            <div className="space-y-3">
              <Link
                to="/app"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#E8741F]"
              >
                {t('nav_home', 'Explore Destinations')}
              </Link>
              <Link
                to="/agents"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#E8741F]"
              >
                {t('nav_guides', 'Local Guides')}
              </Link>
              <Link
                to="/shop"
                onClick={() => setMobileMenuOpen(false)}
                className="block py-2.5 text-sm font-bold text-gray-800 hover:text-[#E8741F]"
              >
                {t('nav_shop', 'Travel Shop')}
              </Link>

              <div className="pt-3 border-t border-gray-100">
                <p className="text-[10px] font-extrabold uppercase tracking-wider text-gray-400 mb-2">Language / ഭാഷ / भाषा</p>
                <div className="grid grid-cols-3 sm:grid-cols-5 gap-1.5 mb-3">
                  {supportedLanguages.map((l) => (
                    <button
                      key={l.code}
                      onClick={() => setLanguage(l.code)}
                      className={`px-2 py-1.5 rounded-xl text-xs font-bold text-center border cursor-pointer transition-all ${
                        language === l.code
                          ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-xs'
                          : 'bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100'
                      }`}
                    >
                      {l.native}
                    </button>
                  ))}
                </div>
              </div>

              <div className="pt-2 border-t border-gray-100 flex flex-col gap-2.5">
                <Link
                  to="/login"
                  onClick={() => setMobileMenuOpen(false)}
                  className="w-full text-center py-2.5 font-bold text-gray-800 border border-gray-200 rounded-xl text-sm"
                >
                  {t('nav_login', 'Log In')}
                </Link>
                <Link
                  to="/signup"
                  onClick={() => setMobileMenuOpen(false)}
                  className="w-full text-center py-2.5 font-bold text-white bg-[#E8741F] rounded-xl shadow-xs text-sm"
                >
                  {t('nav_signup', 'Sign Up')}
                </Link>
                <Link
                  to="/agent/login"
                  onClick={() => setMobileMenuOpen(false)}
                  className="w-full text-center py-2.5 font-bold text-[#8B61F1] bg-purple-50 rounded-xl text-sm"
                >
                  {t('nav_partner', 'Guide Partner Portal')}
                </Link>
              </div>
            </div>
          )}
        </div>
      )}
    </header>
  );
}
