import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { Search, MapPin, Star, ShieldCheck, Sparkles, Compass, Users, ChevronRight } from 'lucide-react';
import WishlistHeartButton from '../components/WishlistHeartButton';

const CATEGORIES = [
  { id: 'all', name: 'All Destinations', icon: '🏔️' },
  { id: 'mountain', name: 'Mountains & Treks', icon: '🏞️' },
  { id: 'beach', name: 'Beaches & Backwaters', icon: '🏖️' },
  { id: 'heritage', name: 'Culture & Heritage', icon: '🏛️' },
  { id: 'wildlife', name: 'Wildlife & Nature', icon: '🌿' },
];

export default function Home() {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [destinations, setDestinations] = useState([]);
  const [agents, setAgents] = useState([]);
  const [announcements, setAnnouncements] = useState([]);
  const [banners, setBanners] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchData = async () => {
    try {
      setLoading(true);
      // 1. Fetch destinations
      const { data: dests } = await supabase
        .from('destinations')
        .select('*');

      setDestinations(dests || []);

      // 2. Fetch top-rated agents with profiles (strictly excluding suspended)
      const { data: agData } = await supabase
        .from('agent_details')
        .select('*, profiles!inner(full_name, photo_url, phone, suspended)')
        .eq('verified', true)
        .eq('suspended', false)
        .order('rating_avg', { ascending: false })
        .limit(10);

      const activeAgents = (agData || []).filter(
        (ag) => ag.suspended !== true && (!ag.profiles || ag.profiles.suspended !== true)
      ).slice(0, 6);
      setAgents(activeAgents);

      // 3. Fetch announcements
      const { data: annData } = await supabase
        .from('announcements')
        .select('*')
        .order('sent_at', { ascending: false })
        .limit(2);
      setAnnouncements(annData || []);

      // 4. Fetch active hero banners
      const { data: bannerData } = await supabase
        .from('banners')
        .select('*')
        .eq('is_active', true)
        .order('display_order', { ascending: true });
      setBanners(bannerData || []);
    } catch (err) {
      console.error('Error fetching home data:', err);
    } finally {
      setLoading(false);
    }
  };


  useEffect(() => {
    fetchData();

    // Real-time subscription for Destinations & Agents
    const destSub = supabase
      .channel('home_destinations_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'destinations' }, () => {
        fetchData();
      })
      .subscribe();

    const agentSub = supabase
      .channel('home_agents_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_details' }, () => {
        fetchData();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => {
        fetchData();
      })
      .subscribe();

    const adminSyncSub = supabase
      .channel('global_admin_sync')
      .on('broadcast', { event: 'agent_status_changed' }, () => {
        fetchData();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(destSub);
      supabase.removeChannel(agentSub);
      supabase.removeChannel(adminSyncSub);
    };
  }, []);

  const filteredDestinations = destinations.filter((dest) => {
    const matchesSearch =
      dest.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      dest.country.toLowerCase().includes(searchQuery.toLowerCase());
    
    if (selectedCategory === 'all') return matchesSearch;
    if (selectedCategory === 'mountain') return matchesSearch && (dest.name.toLowerCase().includes('ladakh') || dest.name.toLowerCase().includes('munnar') || dest.name.toLowerCase().includes('khajjiar') || dest.name.toLowerCase().includes('manali'));
    if (selectedCategory === 'beach') return matchesSearch && (dest.name.toLowerCase().includes('goa') || dest.name.toLowerCase().includes('alleppey') || dest.name.toLowerCase().includes('gokarna'));
    if (selectedCategory === 'heritage') return matchesSearch && (dest.name.toLowerCase().includes('jaipur') || dest.name.toLowerCase().includes('varanasi') || dest.name.toLowerCase().includes('hampi'));
    return matchesSearch;
  });

  return (
    <div className="space-y-12 pb-16 bg-[#F7F6FB] min-h-screen">
      
      {/* ANNOUNCEMENT TICKER BANNER FROM ADMIN */}
      {announcements.length > 0 && (
        <div className="bg-[#FFF7ED] border-b border-orange-200/60 py-3 px-4 sm:px-6">
          <div className="max-w-7xl mx-auto flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5 overflow-hidden">
              <span className="px-2 py-0.5 bg-[#EA580C] text-white text-[10px] font-extrabold rounded-full shrink-0 uppercase tracking-wider">
                📢 Announcement
              </span>
              <span className="text-xs font-bold text-orange-950 truncate">
                {announcements[0].title}: <span className="font-medium text-orange-800">{announcements[0].body}</span>
              </span>
            </div>
            <span className="text-[10px] font-extrabold text-orange-600 shrink-0">Live Notice</span>
          </div>
        </div>
      )}

      {/* HERO BANNER & SEARCH */}
      <section className="relative bg-gradient-to-br from-[#222222] via-[#2A2035] to-[#1A1423] text-white py-16 px-4 sm:px-6 lg:px-8 rounded-b-[40px] shadow-lg overflow-hidden">
        <div className="absolute inset-0 opacity-10 bg-[radial-[#E8741F]_1px,transparent_1px] [background-size:16px_16px]"></div>
        
        <div className="max-w-4xl mx-auto text-center space-y-6 relative z-10">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/10 backdrop-blur-md text-orange-300 text-xs font-bold uppercase tracking-wider border border-white/10">
            <Sparkles className="w-3.5 h-3.5" /> Direct Local Connections Across India
          </div>

          <h1 className="text-4xl sm:text-5xl font-extrabold tracking-tight text-white leading-tight">
            Find Your Vibe. <br className="hidden sm:block" />
            <span className="bg-gradient-to-r from-[#E8741F] to-[#8B61F1] bg-clip-text text-transparent">
              Book Verified Local Guides.
            </span>
          </h1>

          <p className="text-base sm:text-lg text-gray-300 max-w-2xl mx-auto font-medium">
            Explore authentic itineraries created by local experts who know every hidden trail, local food spot, and culture secret.
          </p>

          {/* SEARCH BAR */}
          <div className="max-w-2xl mx-auto bg-white rounded-2xl p-2 shadow-2xl flex items-center gap-2 border border-gray-100">
            <div className="pl-3 text-gray-400">
              <Search className="w-5 h-5" />
            </div>
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Where do you want to go? (e.g. Munnar, Goa, Ladakh...)"
              className="w-full py-2.5 text-gray-900 placeholder-gray-400 text-sm font-semibold focus:outline-none"
            />
            <button className="px-6 py-3 bg-[#E8741F] text-white font-bold text-sm rounded-xl hover:bg-[#D66311] transition-all shrink-0">
              Search
            </button>
          </div>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        
        {/* PROMOTIONAL HERO BANNERS FROM ADMIN */}
        {banners.length > 0 && (
          <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {banners.map((b) => (
              <div
                key={b.id}
                className="relative rounded-3xl overflow-hidden shadow-md h-48 bg-slate-900 text-white flex flex-col justify-end p-6 border border-gray-100 group"
              >
                {b.image_url && (
                  <img
                    src={b.image_url}
                    alt={b.title}
                    className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/40 to-transparent"></div>
                <div className="relative z-10 space-y-1">
                  <span className="px-2.5 py-1 bg-[#E8741F] text-white text-[10px] font-extrabold rounded-md uppercase tracking-wider">
                    {b.badge_text || 'PROMO'}
                  </span>
                  <h3 className="text-lg font-extrabold text-white tracking-tight">{b.title}</h3>
                  {b.subtitle && <p className="text-xs text-gray-200 line-clamp-1 font-medium">{b.subtitle}</p>}
                </div>
              </div>
            ))}
          </section>
        )}
        
        {/* CATEGORY FILTERS */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-extrabold text-gray-900">Explore by Category</h2>
          </div>
          <div className="flex items-center gap-3 overflow-x-auto pb-2 scrollbar-none">
            {CATEGORIES.map((cat) => (
              <button
                key={cat.id}
                onClick={() => setSelectedCategory(cat.id)}
                className={`px-5 py-3 rounded-2xl text-sm font-bold flex items-center gap-2 shrink-0 transition-all border ${
                  selectedCategory === cat.id
                    ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-md scale-[1.02]'
                    : 'bg-white text-gray-700 border-gray-200 hover:border-gray-300 hover:bg-gray-50'
                }`}
              >
                <span className="text-base">{cat.icon}</span>
                {cat.name}
              </button>
            ))}
          </div>
        </section>

        {/* FEATURED DESTINATIONS */}
        <section className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Popular Destinations</h2>
              <p className="text-sm text-gray-500 font-medium">Handpicked spots with active local guides</p>
            </div>
          </div>

          {loading ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
              {[1, 2, 3, 4, 5, 6].map((i) => (
                <div key={i} className="h-64 bg-gray-200 rounded-3xl animate-pulse"></div>
              ))}
            </div>
          ) : filteredDestinations.length === 0 ? (
            <div className="bg-white rounded-3xl p-12 text-center border border-gray-200 space-y-3">
              <Compass className="w-12 h-12 text-gray-400 mx-auto" />
              <h3 className="text-lg font-bold text-gray-800">No destinations match your search</h3>
              <p className="text-sm text-gray-500">Try searching for another keyword or select "All Destinations".</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {filteredDestinations.map((dest) => (
                <div
                  key={dest.id}
                  className="group bg-white rounded-3xl overflow-hidden shadow-sm border border-gray-100 hover:shadow-xl transition-all duration-300 flex flex-col relative"
                >
                  <div className="absolute top-3 right-3 z-10">
                    <WishlistHeartButton type="destination" id={dest.id} size={18} />
                  </div>
                  <Link to={`/destinations/${dest.id}`} className="flex flex-col flex-1">
                    <div className="relative h-52 overflow-hidden bg-gray-100">
                      <img
                        src={dest.cover_image_url || 'https://images.unsplash.com/photo-1506744038136-46273834b3fb'}
                        alt={dest.name}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                      />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent"></div>
                    <div className="absolute bottom-4 left-4 right-4 flex items-center justify-between text-white">
                      <div>
                        <h3 className="text-xl font-extrabold tracking-tight">{dest.name}</h3>
                        <p className="text-xs font-semibold text-gray-200 flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5 text-orange-400" /> {dest.country}
                        </p>
                      </div>
                      <span className="px-3 py-1 bg-white/20 backdrop-blur-md rounded-full text-xs font-bold">
                        {dest.agent_count || 3}+ Guides
                      </span>
                    </div>
                  </div>
                  <div className="p-5 flex items-center justify-between bg-white text-xs font-bold text-gray-600">
                    <span className="text-[#E8741F]">Best Season: Oct – Mar</span>
                    <span className="group-hover:translate-x-1 transition-transform flex items-center gap-1 text-[#8B61F1]">
                      Explore <ChevronRight className="w-4 h-4" />
                    </span>
                  </div>
                </Link>
              </div>
            ))}
            </div>
          )}
        </section>

        {/* TOP RATED AGENTS */}
        <section className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Top Rated Local Guides</h2>
              <p className="text-sm text-gray-500 font-medium">Verified local hosts ready to lead your trip</p>
            </div>
            <Link to="/agents" className="text-sm font-bold text-[#E8741F] hover:underline flex items-center gap-1">
              View All Guides <ChevronRight className="w-4 h-4" />
            </Link>
          </div>

          {loading ? (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-48 bg-gray-200 rounded-3xl animate-pulse"></div>
              ))}
            </div>
          ) : agents.length === 0 ? (
            <div className="bg-white rounded-3xl p-8 text-center border border-gray-200 text-gray-500 text-sm font-semibold">
              No verified agents listed yet.
            </div>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
              {agents.map((ag) => {
                const name = ag.profiles?.full_name || 'Local Guide';
                const photo = ag.profiles?.photo_url || ag.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
                const places = Array.isArray(ag.places_covered) ? ag.places_covered : [];

                return (
                  <div
                    key={ag.id}
                    className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 hover:shadow-lg transition-all flex flex-col justify-between space-y-4 relative group"
                  >
                    <div className="absolute top-5 right-5 z-10">
                      <WishlistHeartButton type="agent" id={ag.id} size={16} />
                    </div>
                    <Link to={`/agents/${ag.id}`} className="block flex-1 space-y-4">
                      <div className="flex items-start gap-4 pr-8">
                      <img
                        src={photo}
                        alt={name}
                        className="w-14 h-14 rounded-2xl object-cover border-2 border-orange-100 shrink-0"
                      />
                      <div className="space-y-1">
                        <div className="flex items-center gap-1.5">
                          <h3 className="font-extrabold text-gray-900 text-base">{name}</h3>
                          <ShieldCheck className="w-4 h-4 text-emerald-500" />
                        </div>
                        <div className="flex items-center gap-2 text-xs font-bold text-gray-600">
                          <span className="flex items-center gap-1 text-amber-500">
                            <Star className="w-3.5 h-3.5 fill-amber-500" /> {ag.rating_avg || 5.0}
                          </span>
                          <span>•</span>
                          <span>{ag.years_experience || 3}+ yrs exp</span>
                        </div>
                      </div>
                    </div>

                    <p className="text-xs text-gray-600 line-clamp-2 leading-relaxed">
                      {ag.bio || 'Passionate local guide specializing in cultural tours, local food exploration, and mountain trails.'}
                    </p>

                    {Array.isArray(ag.specialization_tags) && ag.specialization_tags.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 pt-1">
                        {ag.specialization_tags.slice(0, 2).map((t, idx) => (
                          <span key={idx} className="px-2 py-0.5 bg-orange-50 text-[#E8741F] border border-orange-200/60 font-extrabold text-[10px] rounded-md">
                            🏷️ {t}
                          </span>
                        ))}
                      </div>
                    )}

                    <div className="pt-3 border-t border-gray-100 flex items-center justify-between">
                      <div>
                        <span className="text-xs font-bold text-gray-400 uppercase">Rate per day</span>
                        <p className="text-base font-extrabold text-[#E8741F]">₹{ag.price_per_day || 1500}/day</p>
                      </div>
                      <span className="px-4 py-2 bg-orange-50 text-[#E8741F] font-bold text-xs rounded-xl hover:bg-orange-100 transition-colors">
                        Check Availability
                      </span>
                    </div>
                  </Link>
                </div>
              );
            })}
            </div>
          )}
        </section>

      </div>
    </div>
  );
}
