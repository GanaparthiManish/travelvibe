import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { Search, Star, ShieldCheck, MapPin, SlidersHorizontal, ArrowRight, UserCheck } from 'lucide-react';
import WishlistHeartButton from '../components/WishlistHeartButton';

const DEFAULT_TAGS = [
  'Wildlife Expert',
  'Photography Tours',
  'Family-Friendly',
  'Solo Traveller Safe',
  'Adventure/Trekking',
  'Cultural & Heritage',
  'Budget-Friendly',
  'Culinary & Food Walks',
];

export default function AgentListing() {
  const [searchQuery, setSearchQuery] = useState('');
  const [priceFilter, setPriceFilter] = useState('all');
  const [selectedTag, setSelectedTag] = useState('all');
  const [masterTags, setMasterTags] = useState(DEFAULT_TAGS);
  const [agents, setAgents] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchMasterTags = async () => {
    try {
      const { data } = await supabase
        .from('app_settings')
        .select('value')
        .eq('key', 'specialization_tags_master')
        .maybeSingle();
      if (data && Array.isArray(data.value) && data.value.length > 0) {
        setMasterTags(data.value);
      }
    } catch (_) {}
  };

  const fetchAgents = async () => {
    try {
      setLoading(true);
      const { data } = await supabase
        .from('agent_details')
        .select('*, profiles!inner(full_name, photo_url, phone, suspended)')
        .eq('verified', true)
        .eq('suspended', false)
        .order('rating_avg', { ascending: false });

      // Filter out any suspended agents on BOTH agent_details AND profiles
      const activeAgents = (data || []).filter(
        (ag) => ag.suspended !== true && (!ag.profiles || ag.profiles.suspended !== true)
      );
      setAgents(activeAgents);
    } catch (err) {
      console.error('Error fetching agents:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMasterTags();
    fetchAgents();

    const sub = supabase
      .channel('agent_listing_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_details' }, () => {
        fetchAgents();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => {
        fetchAgents();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'app_settings' }, () => {
        fetchMasterTags();
      })
      .subscribe();

    const adminSyncSub = supabase
      .channel('global_admin_sync')
      .on('broadcast', { event: 'agent_status_changed' }, () => {
        fetchAgents();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(sub);
      supabase.removeChannel(adminSyncSub);
    };
  }, []);

  const filteredAgents = agents.filter((ag) => {
    const name = ag.profiles?.full_name?.toLowerCase() || '';
    const bio = ag.bio?.toLowerCase() || '';
    const places = Array.isArray(ag.places_covered) ? ag.places_covered.join(' ').toLowerCase() : '';
    const q = searchQuery.toLowerCase();

    const matchesQuery = name.includes(q) || bio.includes(q) || places.includes(q);

    let matchesPrice = true;
    if (priceFilter === 'low') matchesPrice = ag.price_per_day <= 1500;
    if (priceFilter === 'mid') matchesPrice = ag.price_per_day > 1500 && ag.price_per_day <= 3000;
    if (priceFilter === 'high') matchesPrice = ag.price_per_day > 3000;

    const matchesTag =
      selectedTag === 'all' ||
      (Array.isArray(ag.specialization_tags) && ag.specialization_tags.includes(selectedTag));

    return matchesQuery && matchesPrice && matchesTag;
  });

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      
      {/* HEADER */}
      <section className="bg-[#222222] text-white py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto space-y-5">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-extrabold text-orange-400 uppercase tracking-wider">
            <UserCheck className="w-4 h-4" /> 100% Verified Local Hosts
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight">Browse Local Travel Guides</h1>
          <p className="text-sm text-gray-300 max-w-xl font-medium">
            Connect directly with experienced local experts across top destinations in India. Custom itineraries, safety assured.
          </p>

          {/* SEARCH & FILTERS */}
          <div className="pt-2 grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div className="sm:col-span-2 relative">
              <Search className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search by name, destination (e.g. Munnar, Goa, Leh)..."
                className="w-full pl-11 pr-4 py-3 bg-white text-gray-900 rounded-xl font-medium text-sm focus:outline-none"
              />
            </div>
            <div>
              <select
                value={priceFilter}
                onChange={(e) => setPriceFilter(e.target.value)}
                className="w-full py-3 px-4 bg-white text-gray-900 rounded-xl font-bold text-sm focus:outline-none"
              >
                <option value="all">All Daily Rates</option>
                <option value="low">Under ₹1,500/day</option>
                <option value="mid">₹1,500 – ₹3,000/day</option>
                <option value="high">Above ₹3,000/day</option>
              </select>
            </div>
          </div>

          {/* SPECIALIZATION TAGS FILTER CHIPS */}
          <div className="pt-2">
            <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-none">
              <button
                onClick={() => setSelectedTag('all')}
                className={`px-3.5 py-1.5 rounded-full text-xs font-extrabold shrink-0 transition-all border ${
                  selectedTag === 'all'
                    ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-sm'
                    : 'bg-white/10 text-gray-200 border-white/20 hover:bg-white/20'
                }`}
              >
                All Specializations
              </button>
              {masterTags.map((tag, idx) => (
                <button
                  key={idx}
                  onClick={() => setSelectedTag(tag)}
                  className={`px-3.5 py-1.5 rounded-full text-xs font-extrabold shrink-0 transition-all border ${
                    selectedTag === tag
                      ? 'bg-[#E8741F] text-white border-[#E8741F] shadow-sm'
                      : 'bg-white/10 text-gray-200 border-white/20 hover:bg-white/20'
                  }`}
                >
                  {tag}
                </button>
              ))}
            </div>
          </div>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} className="h-56 bg-gray-200 rounded-3xl animate-pulse"></div>
            ))}
          </div>
        ) : filteredAgents.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-gray-200 space-y-3">
            <UserCheck className="w-12 h-12 text-gray-400 mx-auto" />
            <h3 className="text-lg font-bold text-gray-800">No verified local guides match your search</h3>
            <p className="text-sm text-gray-500">Try clearing your filters or searching for another location.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredAgents.map((ag) => {
              const name = ag.profiles?.full_name || 'Local Guide';
              const photo = ag.profiles?.photo_url || ag.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
              const places = Array.isArray(ag.places_covered) ? ag.places_covered : [];

              return (
                <div key={ag.id} className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-4 flex flex-col justify-between hover:shadow-lg transition-all relative group">
                  <div className="absolute top-5 right-5 z-10">
                    <WishlistHeartButton type="agent" id={ag.id} size={16} />
                  </div>
                  <div className="space-y-3 pr-8">
                    <div className="flex items-start gap-4">
                      <img src={photo} alt={name} className="w-16 h-16 rounded-2xl object-cover border-2 border-orange-100 shrink-0" />
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
                          <span>{ag.years_experience || 2}+ yrs exp</span>
                        </div>
                      </div>
                    </div>

                    <p className="text-xs text-gray-600 line-clamp-3 leading-relaxed">
                      {ag.bio || 'Experienced local tour guide. Specializes in customized trips, culture & food, and hidden scenic spots.'}
                    </p>

                    {places.length > 0 && (
                      <div className="flex flex-wrap gap-1.5">
                        {places.slice(0, 3).map((p, idx) => (
                          <span key={idx} className="px-2.5 py-1 bg-gray-100 text-gray-700 font-bold text-[11px] rounded-lg">
                            📍 {p}
                          </span>
                        ))}
                      </div>
                    )}

                    {Array.isArray(ag.specialization_tags) && ag.specialization_tags.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 pt-1">
                        {ag.specialization_tags.slice(0, 3).map((t, idx) => (
                          <span key={idx} className="px-2 py-0.5 bg-orange-50 text-[#E8741F] border border-orange-200/60 font-extrabold text-[10px] rounded-md">
                            🏷️ {t}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  <div className="pt-3 border-t border-gray-100 flex items-center justify-between">
                    <div>
                      <span className="text-xs font-bold text-gray-400 uppercase">Rate per day</span>
                      <p className="text-base font-extrabold text-[#E8741F]">₹{ag.price_per_day || 1500}/day</p>
                    </div>
                    <Link
                      to={`/agents/${ag.id}`}
                      className="px-4 py-2 bg-[#8B61F1] text-white font-bold text-xs rounded-xl shadow-xs hover:bg-purple-700 transition-all"
                    >
                      View Profile
                    </Link>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
