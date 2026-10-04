import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { ShieldCheck, ArrowRight, Star, MapPin, Users, Zap, Compass, CheckCircle2, ChevronRight } from 'lucide-react';

export default function LandingPage() {
  const [destinations, setDestinations] = useState([]);
  const [agents, setAgents] = useState([]);
  const [loading, setLoading] = useState(true);

  const loadLandingData = async () => {
    try {
      setLoading(true);
      // Fetch top featured destinations
      const { data: dests } = await supabase
        .from('destinations')
        .select('*')
        .limit(3);

      // Fetch top verified guides with profile join (excluding suspended)
      const { data: ags } = await supabase
        .from('agent_details')
        .select('*, profiles!inner(full_name, photo_url, suspended)')
        .eq('verified', true)
        .order('rating_avg', { ascending: false })
        .limit(10);

      const activeAgents = (ags || []).filter((ag) => ag.profiles && ag.profiles.suspended !== true).slice(0, 3);

      setDestinations(dests || []);
      setAgents(activeAgents);
    } catch (err) {
      console.error('Error loading landing page data:', err);
    } finally {
      setLoading(false);
    }
  };


  useEffect(() => {
    loadLandingData();

    // Real-time channel listener for Admin updates (agent removal/addition, destination edits)
    const channel = supabase
      .channel('landing_realtime_sync')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_details' }, () => loadLandingData())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => loadLandingData())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'destinations' }, () => loadLandingData())
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);


  return (
    <div className="space-y-20 pb-20 bg-[#F7F6FB]">
      
      {/* HERO SECTION */}
      <section className="relative bg-gradient-to-br from-[#1A102F] via-[#2D1B36] to-[#120F1C] pt-16 sm:pt-20 pb-16 sm:pb-24 px-4 sm:px-6 lg:px-8 rounded-b-[40px] sm:rounded-b-[56px] shadow-2xl overflow-hidden border-b border-purple-900/30">
        
        {/* BACKGROUND GLOW ACCENT */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[700px] h-[350px] bg-gradient-to-r from-[#E8741F]/25 via-[#8B61F1]/30 to-[#E8741F]/20 blur-[120px] pointer-events-none rounded-full"></div>

        <div className="max-w-4xl mx-auto text-center space-y-8 relative z-10">
          
          {/* BADGE */}
          <div className="inline-flex items-center gap-2.5 px-4 py-2 rounded-full bg-white/10 backdrop-blur-md border border-white/20 shadow-inner">
            <ShieldCheck className="w-4 h-4 text-emerald-400" />
            <span className="text-amber-300 text-xs font-black uppercase tracking-wider">
              India's Premier Local Guide Marketplace
            </span>
          </div>

          {/* MAIN HEADING WITH GUARANTEED CONTRAST */}
          <h1 className="text-4xl sm:text-6xl font-black tracking-tight leading-[1.15]" style={{ color: '#FFFFFF' }}>
            Authentic Local Travel, <br />
            <span className="bg-gradient-to-r from-[#FF8D3B] via-amber-300 to-[#A78BFA] bg-clip-text text-transparent drop-shadow-sm">
              Guided by Verified Locals.
            </span>
          </h1>

          {/* SUBTITLE WITH GUARANTEED CONTRAST */}
          <p className="text-base sm:text-xl max-w-2xl mx-auto font-semibold leading-relaxed" style={{ color: '#E2E8F0' }}>
            Skip the tourist traps. Connect directly with handpicked local experts who craft custom itineraries, ensure safety, and unlock secret spots.
          </p>

          {/* CTA BUTTONS WITH EXPLICIT SPACING & CONTRAST */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
            <Link
              to="/app"
              className="w-full sm:w-auto px-8 py-4 bg-gradient-to-r from-[#E8741F] to-[#D66311] text-white font-black text-base rounded-2xl shadow-xl shadow-orange-500/25 hover:shadow-orange-500/40 hover:scale-[1.02] active:scale-95 transition-all flex items-center justify-center gap-2.5"
            >
              Find a Trip <ArrowRight className="w-5 h-5" />
            </Link>

            <Link
              to="/agent/signup"
              className="w-full sm:w-auto px-8 py-4 bg-white/10 backdrop-blur-md border border-white/30 font-black text-base rounded-2xl hover:bg-white/20 hover:border-white/50 hover:scale-[1.02] active:scale-95 transition-all flex items-center justify-center gap-2.5"
              style={{ color: '#FFFFFF' }}
            >
              Become an Agent <ShieldCheck className="w-5 h-5 text-emerald-400" />
            </Link>
          </div>

          {/* STATS METRICS GRID CONTAINED INSIDE GLASS CARD */}
          <div className="mt-12 bg-white/5 backdrop-blur-md border border-white/10 rounded-3xl p-6 sm:p-8 grid grid-cols-2 md:grid-cols-4 gap-6 text-center shadow-2xl">
            <div className="space-y-1">
              <p className="text-3xl sm:text-4xl font-black" style={{ color: '#FFFFFF' }}>500+</p>
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">Verified Guides</span>
            </div>
            <div className="space-y-1">
              <p className="text-3xl sm:text-4xl font-black" style={{ color: '#FFFFFF' }}>50+</p>
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">Destinations</span>
            </div>
            <div className="space-y-1">
              <p className="text-3xl sm:text-4xl font-black text-amber-300">4.9 ★</p>
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">Average Rating</span>
            </div>
            <div className="space-y-1">
              <p className="text-3xl sm:text-4xl font-black text-emerald-400">100%</p>
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider">Verified Safety</span>
            </div>
          </div>

        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        <div className="text-center space-y-2">
          <span className="text-xs font-black uppercase tracking-widest text-[#E8741F]">Simple & Safe</span>
          <h2 className="text-3xl sm:text-4xl font-black text-gray-900 tracking-tight">How TravelVibe Works</h2>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          
          <div className="bg-white rounded-3xl p-8 shadow-sm border border-gray-200/80 space-y-4 text-center hover:shadow-md transition-all">
            <div className="w-14 h-14 bg-orange-100 text-[#E8741F] rounded-2xl flex items-center justify-center mx-auto text-xl font-black shadow-inner">
              1
            </div>
            <h3 className="text-xl font-black text-gray-900">Choose a Destination</h3>
            <p className="text-sm text-gray-600 font-semibold leading-relaxed">
              Browse handpicked destinations across Kerala, Himachal, Ladakh, Rajasthan & Goa.
            </p>
          </div>

          <div className="bg-white rounded-3xl p-8 shadow-sm border border-gray-200/80 space-y-4 text-center hover:shadow-md transition-all">
            <div className="w-14 h-14 bg-purple-100 text-[#8B61F1] rounded-2xl flex items-center justify-center mx-auto text-xl font-black shadow-inner">
              2
            </div>
            <h3 className="text-xl font-black text-gray-900">Select Your Local Guide</h3>
            <p className="text-sm text-gray-600 font-semibold leading-relaxed">
              Review verified guide bios, ratings, spoken languages, and price per day.
            </p>
          </div>

          <div className="bg-white rounded-3xl p-8 shadow-sm border border-gray-200/80 space-y-4 text-center hover:shadow-md transition-all">
            <div className="w-14 h-14 bg-emerald-100 text-emerald-600 rounded-2xl flex items-center justify-center mx-auto text-xl font-black shadow-inner">
              3
            </div>
            <h3 className="text-xl font-black text-gray-900">Book & Chat Real-Time</h3>
            <p className="text-sm text-gray-600 font-semibold leading-relaxed">
              Request dates, confirm meeting points, and chat live with your guide before arriving.
            </p>
          </div>

        </div>
      </section>

      {/* FEATURED DESTINATIONS PREVIEW */}
      {destinations.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-xs font-black uppercase tracking-widest text-[#E8741F]">Popular Hotspots</span>
              <h2 className="text-3xl font-black text-gray-900 tracking-tight">Explore Top Destinations</h2>
            </div>
            <Link to="/app" className="text-sm font-extrabold text-[#E8741F] hover:underline flex items-center gap-1">
              View All <ChevronRight className="w-4 h-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {destinations.map((dest) => (
              <Link
                key={dest.id}
                to={`/destinations/${dest.id}`}
                className="group bg-white rounded-3xl overflow-hidden shadow-sm border border-gray-200 hover:shadow-xl transition-all duration-300 flex flex-col"
              >
                <div className="relative h-56 overflow-hidden bg-gray-100">
                  <img
                    src={dest.cover_image_url || 'https://images.unsplash.com/photo-1506744038136-46273834b3fb'}
                    alt={dest.name}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent"></div>
                  <div className="absolute bottom-4 left-4 right-4 text-white">
                    <h3 className="text-2xl font-black tracking-tight" style={{ color: '#FFFFFF' }}>{dest.name}</h3>
                    <p className="text-xs font-bold text-gray-200 flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 text-orange-400" /> {dest.country}
                    </p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>
      )}

      {/* WHY CHOOSE US */}
      <section className="bg-white py-20 border-y border-gray-200/80">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
          <div className="text-center space-y-2">
            <span className="text-xs font-black uppercase tracking-widest text-[#8B61F1]">Trusted Experience</span>
            <h2 className="text-3xl sm:text-4xl font-black text-gray-900 tracking-tight">Why Travellers & Guides Choose TravelVibe</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="p-8 bg-orange-50/60 rounded-3xl border border-orange-200/80 space-y-4">
              <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center shadow-xs text-[#E8741F]">
                <ShieldCheck className="w-7 h-7" />
              </div>
              <h3 className="text-xl font-black text-gray-900">Strict Background & Document Verification</h3>
              <p className="text-sm text-gray-700 font-semibold leading-relaxed">
                Every local guide on TravelVibe submits government identification and undergoes background verification before accepting bookings.
              </p>
            </div>

            <div className="p-8 bg-purple-50/60 rounded-3xl border border-purple-200/80 space-y-4">
              <div className="w-12 h-12 bg-white rounded-2xl flex items-center justify-center shadow-xs text-[#8B61F1]">
                <Zap className="w-7 h-7" />
              </div>
              <h3 className="text-xl font-black text-gray-900">Real-time Cross Platform Sync</h3>
              <p className="text-sm text-gray-700 font-semibold leading-relaxed">
                Instant booking requests, live chat, and availability calendars synced seamlessly across web, iOS, and Android Flutter apps.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* BOTTOM CTA */}
      <section className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-gradient-to-r from-[#E8741F] to-[#8B61F1] rounded-3xl p-10 sm:p-14 text-white text-center space-y-6 shadow-2xl relative overflow-hidden">
          <h2 className="text-3xl sm:text-4xl font-black tracking-tight" style={{ color: '#FFFFFF' }}>
            Ready to Explore India Like a Local?
          </h2>
          <p className="text-base sm:text-lg max-w-xl mx-auto font-semibold" style={{ color: '#F1F5F9' }}>
            Start your journey today or list your local guide services on India's top travel platform.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-2">
            <Link
              to="/app"
              className="w-full sm:w-auto px-8 py-4 bg-white text-gray-900 font-black text-sm rounded-2xl shadow-md hover:bg-gray-100 transition-all"
            >
              Explore Destinations
            </Link>
            <Link
              to="/agent/signup"
              className="w-full sm:w-auto px-8 py-4 bg-black/20 backdrop-blur-md text-white font-black text-sm rounded-2xl border border-white/30 hover:bg-black/30 transition-all"
              style={{ color: '#FFFFFF' }}
            >
              Apply as Local Guide
            </Link>
          </div>
        </div>
      </section>

    </div>
  );
}

