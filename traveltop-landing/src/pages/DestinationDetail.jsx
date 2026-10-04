import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { MapPin, Calendar, Compass, Star, ShieldCheck, Users, ArrowLeft, ChevronRight } from 'lucide-react';
import WishlistHeartButton from '../components/WishlistHeartButton';

export default function DestinationDetail() {
  const { id } = useParams();
  const [destination, setDestination] = useState(null);
  const [agents, setAgents] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchDestinationData = async () => {
    try {
      setLoading(true);
      // Fetch destination info
      const { data: dest } = await supabase
        .from('destinations')
        .select('*')
        .eq('id', id)
        .maybeSingle();

      setDestination(dest);

      if (dest) {
        // Fetch agents that cover this destination
        const destNameLower = dest.name.toLowerCase();
        const { data: agData } = await supabase
          .from('agent_details')
          .select('*, profiles!inner(full_name, photo_url, phone, suspended)')
          .eq('verified', true)
          .eq('suspended', false);

        if (agData) {
          const matchingAgents = agData
            .filter((ag) => ag.suspended !== true && (!ag.profiles || ag.profiles.suspended !== true))
            .filter((ag) => {
              const places = Array.isArray(ag.places_covered)
                ? ag.places_covered.map((p) => p.toLowerCase())
                : [];
              return (
                places.length === 0 ||
                places.some((p) => p.includes(destNameLower) || destNameLower.includes(p))
              );
            });
          setAgents(matchingAgents);
        }
      }
    } catch (err) {
      console.error('Error fetching destination:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDestinationData();

    // Real-time subscription
    const channel = supabase
      .channel(`dest_detail_${id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'destinations', filter: `id=eq.${id}` }, () => {
        fetchDestinationData();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [id]);

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-12 space-y-6 animate-pulse">
        <div className="h-96 bg-gray-200 rounded-3xl"></div>
        <div className="h-10 w-1/3 bg-gray-200 rounded-xl"></div>
        <div className="h-24 bg-gray-200 rounded-2xl"></div>
      </div>
    );
  }

  if (!destination) {
    return (
      <div className="max-w-md mx-auto my-16 p-8 bg-white rounded-3xl text-center border border-gray-200 space-y-4">
        <Compass className="w-12 h-12 text-gray-400 mx-auto" />
        <h2 className="text-xl font-bold text-gray-800">Destination Not Found</h2>
        <p className="text-sm text-gray-500">The destination you are looking for does not exist or has been removed.</p>
        <Link to="/app" className="inline-block px-5 py-2.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl">
          Back to Explore
        </Link>
      </div>
    );
  }

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-10">
      
      {/* COVER HERO */}
      <div className="relative h-[450px] overflow-hidden bg-gray-900">
        <img
          src={destination.cover_image_url || 'https://images.unsplash.com/photo-1506744038136-46273834b3fb'}
          alt={destination.name}
          className="w-full h-full object-cover opacity-80"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/30 to-transparent"></div>
        
        <div className="absolute top-6 left-6 z-10">
          <Link
            to="/app"
            className="flex items-center gap-2 px-4 py-2 bg-white/20 backdrop-blur-md text-white font-bold text-sm rounded-full hover:bg-white/30 transition-all"
          >
            <ArrowLeft className="w-4 h-4" /> Back to Destinations
          </Link>
        </div>

        <div className="absolute top-6 right-6 z-10">
          <WishlistHeartButton
            type="destination"
            id={destination.id}
            size={22}
            className="p-3 bg-white/20 backdrop-blur-md text-white hover:bg-white hover:text-rose-500"
          />
        </div>

        <div className="absolute bottom-8 left-6 right-6 max-w-7xl mx-auto text-white space-y-2">
          <span className="px-3 py-1 bg-orange-500/90 backdrop-blur-md rounded-full text-xs font-extrabold uppercase tracking-wider">
            Featured Location
          </span>
          <h1 className="text-4xl sm:text-5xl font-extrabold tracking-tight">{destination.name}</h1>
          <p className="text-lg text-gray-200 flex items-center gap-1.5 font-medium">
            <MapPin className="w-5 h-5 text-orange-400" /> {destination.country}
          </p>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        
        {/* OVERVIEW INFO GRID */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <div className="w-10 h-10 bg-orange-50 rounded-xl flex items-center justify-center text-[#E8741F]">
              <Calendar className="w-5 h-5" />
            </div>
            <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider">Best Season</h3>
            <p className="text-lg font-extrabold text-gray-900">{destination.best_season || 'October to March'}</p>
            <p className="text-xs text-gray-500">Ideal weather for sightseeing and outdoor trekking</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <div className="w-10 h-10 bg-purple-50 rounded-xl flex items-center justify-center text-[#8B61F1]">
              <Users className="w-5 h-5" />
            </div>
            <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider">Local Experts</h3>
            <p className="text-lg font-extrabold text-gray-900">{agents.length} Verified Guides Available</p>
            <p className="text-xs text-gray-500">Ready for custom itinerary & booking</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <div className="w-10 h-10 bg-emerald-50 rounded-xl flex items-center justify-center text-emerald-600">
              <Compass className="w-5 h-5" />
            </div>
            <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider">Key Highlights</h3>
            <p className="text-lg font-extrabold text-gray-900">{destination.name} Circuit</p>
            <p className="text-xs text-gray-500">Scenic viewpoints, local markets & cultural sites</p>
          </div>
        </div>

        {/* AVAILABLE AGENTS */}
        <section className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Available Guides for {destination.name}</h2>
              <p className="text-sm font-medium text-gray-500">Book directly with local hosts for custom itineraries</p>
            </div>
          </div>

          {agents.length === 0 ? (
            <div className="bg-white rounded-3xl p-10 text-center border border-gray-200 space-y-3">
              <Users className="w-10 h-10 text-gray-400 mx-auto" />
              <h3 className="text-base font-bold text-gray-800">No agents registered for this destination yet</h3>
              <p className="text-xs text-gray-500">Check out other local guides in our main directory.</p>
              <Link to="/agents" className="inline-block px-4 py-2 bg-[#8B61F1] text-white text-xs font-bold rounded-xl">
                Browse All Local Guides
              </Link>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {agents.map((ag) => {
                const name = ag.profiles?.full_name || 'Local Guide';
                const photo = ag.profiles?.photo_url || ag.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';

                return (
                  <div key={ag.id} className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-4 flex flex-col justify-between relative group">
                    <div className="absolute top-4 right-4 z-10">
                      <WishlistHeartButton type="agent" id={ag.id} size={16} />
                    </div>

                    <div className="flex items-start gap-4 pr-8">
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
                      {ag.bio || `Expert guide based in ${destination.name}. Speeds up logistics, local food tours, and trekking routes.`}
                    </p>

                    <div className="pt-3 border-t border-gray-100 flex items-center justify-between">
                      <div>
                        <span className="text-xs font-bold text-gray-400 uppercase">Rate per day</span>
                        <p className="text-base font-extrabold text-[#E8741F]">₹{ag.price_per_day || 1500}/day</p>
                      </div>
                      <Link
                        to={`/book/${ag.id}`}
                        className="px-5 py-2.5 bg-[#E8741F] text-white font-bold text-xs rounded-xl shadow-sm hover:bg-[#D66311] transition-all"
                      >
                        Book Guide
                      </Link>
                    </div>
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
