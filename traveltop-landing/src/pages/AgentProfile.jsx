import React, { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { ShieldCheck, Star, MapPin, Calendar, CheckCircle2, MessageSquare, ArrowLeft, Utensils, Home as HomeIcon, Car, Play, Sparkles } from 'lucide-react';
import WishlistHeartButton from '../components/WishlistHeartButton';
import GuideStoryViewer from '../components/GuideStoryViewer';

export default function AgentProfile() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [agent, setAgent] = useState(null);
  const [reviews, setReviews] = useState([]);
  const [stories, setStories] = useState([]);
  const [showStoryViewer, setShowStoryViewer] = useState(false);
  const [loading, setLoading] = useState(true);

  const fetchAgentProfile = async () => {
    try {
      setLoading(true);
      const { data: ag } = await supabase
        .from('agent_details')
        .select('*, profiles!inner(full_name, photo_url, phone, suspended)')
        .eq('id', id)
        .maybeSingle();

      if (ag && (ag.suspended === true || ag.profiles?.suspended === true)) {
        setAgent(null);
        return;
      }

      setAgent(ag);

      if (ag) {
        const { data: revs } = await supabase
          .from('reviews')
          .select('*, profiles!reviews_traveller_id_fkey(full_name, photo_url)')
          .eq('agent_id', id)
          .order('created_at', { ascending: false });
        setReviews(revs || []);
      }
    } catch (err) {
      console.error('Error fetching agent profile:', err);
    } finally {
      setLoading(false);
    }
  };

  const fetchStories = async () => {
    try {
      const { data } = await supabase
        .from('guide_stories')
        .select('*')
        .eq('agent_id', id)
        .order('display_order', { ascending: true })
        .order('created_at', { ascending: false });
      setStories(data || []);
    } catch (_) {}
  };

  useEffect(() => {
    fetchAgentProfile();
    fetchStories();

    const sub = supabase
      .channel(`agent_profile_${id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_details', filter: `id=eq.${id}` }, () => {
        fetchAgentProfile();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'guide_stories', filter: `agent_id=eq.${id}` }, () => {
        fetchStories();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(sub);
    };
  }, [id]);

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 space-y-6 animate-pulse">
        <div className="h-64 bg-gray-200 rounded-3xl"></div>
        <div className="h-10 w-1/3 bg-gray-200 rounded-xl"></div>
      </div>
    );
  }

  if (!agent) {
    return (
      <div className="max-w-md mx-auto my-16 p-8 bg-white rounded-3xl text-center border border-gray-200 space-y-4">
        <ShieldCheck className="w-12 h-12 text-gray-400 mx-auto" />
        <h2 className="text-xl font-bold text-gray-800">Agent Profile Not Found</h2>
        <p className="text-sm text-gray-500">The agent profile you are looking for does not exist.</p>
        <Link to="/agents" className="inline-block px-5 py-2.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl">
          Back to Guides
        </Link>
      </div>
    );
  }

  const name = agent.profiles?.full_name || 'Local Guide';
  const photo = agent.profiles?.photo_url || agent.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
  const places = Array.isArray(agent.places_covered) ? agent.places_covered : [];
  const languages = Array.isArray(agent.languages) ? agent.languages : ['English', 'Hindi'];

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      
      {/* TOP HEADER */}
      <div className="bg-white border-b border-gray-100 py-6 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto space-y-4">
          <Link to="/agents" className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900">
            <ArrowLeft className="w-4 h-4" /> Back to Guides Directory
          </Link>

          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
            <div className="flex items-center gap-5">
              {stories.length > 0 ? (
                <div
                  onClick={() => setShowStoryViewer(true)}
                  className="relative p-[3px] bg-gradient-to-tr from-amber-500 via-[#E8741F] to-[#8B61F1] rounded-3xl cursor-pointer hover:scale-105 transition-all shadow-md group shrink-0"
                  title="Click to view Guide's Stories"
                >
                  <img
                    src={photo}
                    alt={name}
                    className="w-20 h-20 rounded-[22px] object-cover border-2 border-white"
                  />
                  <div className="absolute -bottom-2 -right-2 px-2 py-0.5 bg-[#E8741F] text-white text-[9px] font-extrabold rounded-full flex items-center gap-1 shadow-sm uppercase tracking-wider">
                    <Play className="w-2.5 h-2.5 fill-white" /> Stories
                  </div>
                </div>
              ) : (
                <img
                  src={photo}
                  alt={name}
                  className="w-20 h-20 rounded-3xl object-cover border-2 border-orange-100 shadow-md shrink-0"
                />
              )}

              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <h1 className="text-2xl font-extrabold text-gray-900">{name}</h1>
                  <ShieldCheck className="w-5 h-5 text-emerald-500" />
                  <span className="px-2.5 py-0.5 bg-emerald-50 text-emerald-700 text-[10px] font-extrabold uppercase rounded-full">
                    Verified Guide
                  </span>
                </div>
                <div className="flex items-center gap-3 text-xs font-bold text-gray-600">
                  <span className="flex items-center gap-1 text-amber-500">
                    <Star className="w-4 h-4 fill-amber-500" /> {agent.rating_avg || 5.0} ({reviews.length} reviews)
                  </span>
                  <span>•</span>
                  <span>{agent.years_experience || 2}+ years experience</span>
                </div>

                {Array.isArray(agent.specialization_tags) && agent.specialization_tags.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 pt-1.5">
                    {agent.specialization_tags.map((tag, idx) => (
                      <span
                        key={idx}
                        className="px-2.5 py-0.5 bg-orange-50 text-[#E8741F] border border-orange-200 font-extrabold text-[10px] rounded-lg flex items-center gap-1"
                      >
                        <span>🏷️</span>
                        <span>{tag}</span>
                      </span>
                    ))}
                  </div>
                )}
              </div>
            </div>

            <div className="flex items-center gap-3 w-full sm:w-auto">
              <div>
                <span className="text-xs font-bold text-gray-400 uppercase">Rate per day</span>
                <p className="text-2xl font-extrabold text-[#E8741F]">₹{agent.price_per_day || 1500}/day</p>
              </div>
              <div className="flex items-center gap-2 flex-1 sm:flex-initial">
                <WishlistHeartButton
                  type="agent"
                  id={agent.id}
                  size={20}
                  className="p-3.5 bg-gray-100 hover:bg-gray-200 border border-gray-200 text-gray-700"
                />
                <Link
                  to={`/book/${agent.id}`}
                  className="flex-1 px-6 py-3 bg-[#E8741F] text-white font-bold text-sm rounded-2xl shadow-md hover:bg-[#D66311] transition-all text-center"
                >
                  Book Guide Now
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
        
        {/* BIO & DETAILS */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-6">
          <div>
            <h2 className="text-lg font-extrabold text-gray-900 mb-2">About {name}</h2>
            <p className="text-sm text-gray-600 leading-relaxed font-medium">
              {agent.bio || 'Experienced local guide passionate about providing personalized trips, hidden local gems, authentic food tours, and safe mountain treks.'}
            </p>
          </div>

          {/* ESTIMATED DAILY EXPENSES - INFORMATIONAL ONLY */}
          <div className="p-4 bg-amber-50/80 border border-amber-200 rounded-2xl flex items-start gap-3">
            <span className="text-xl">💵</span>
            <div className="space-y-0.5">
              <h4 className="text-xs font-extrabold text-amber-900">
                Estimated cash to carry per day: ₹{agent.estimated_daily_expenses || 1500}
              </h4>
              <p className="text-xs text-amber-800 font-medium leading-relaxed">
                (accommodation, food, local transport — pay directly, not through the app)
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 pt-6 border-t border-gray-100">
            <div>
              <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Places Covered</h3>
              <div className="flex flex-wrap gap-2">
                {places.length > 0 ? (
                  places.map((p, idx) => (
                    <span key={idx} className="px-3 py-1 bg-orange-50 text-[#E8741F] font-bold text-xs rounded-xl">
                      📍 {p}
                    </span>
                  ))
                ) : (
                  <span className="text-xs text-gray-500 font-medium">All Major Regional Circuits</span>
                )}
              </div>
            </div>

            <div>
              <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Languages Spoken</h3>
              <div className="flex flex-wrap gap-2">
                {languages.map((l, idx) => (
                  <span key={idx} className="px-3 py-1 bg-purple-50 text-[#8B61F1] font-bold text-xs rounded-xl">
                    🗣️ {l}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {/* SPECIALIZATIONS */}
          {Array.isArray(agent.specialization_tags) && agent.specialization_tags.length > 0 && (
            <div className="pt-6 border-t border-gray-100">
              <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5 text-[#E8741F]" /> Guide Specialization Tags
              </h3>
              <div className="flex flex-wrap gap-2">
                {agent.specialization_tags.map((tag, idx) => (
                  <span
                    key={idx}
                    className="px-3.5 py-1.5 bg-gradient-to-r from-orange-50 to-amber-50 text-[#E8741F] border border-orange-200 font-extrabold text-xs rounded-xl shadow-xs flex items-center gap-1"
                  >
                    🏷️ {tag}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* INCLUSIONS */}
          <div className="pt-6 border-t border-gray-100">
            <h3 className="text-xs font-bold text-gray-400 uppercase tracking-wider mb-3">Service Inclusions</h3>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className={`p-3.5 rounded-2xl border flex items-center gap-3 text-xs font-bold ${agent.meals_included ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-gray-50 border-gray-200 text-gray-400'}`}>
                <Utensils className="w-4 h-4" /> Meals Included: {agent.meals_included ? 'Yes' : 'No'}
              </div>
              <div className={`p-3.5 rounded-2xl border flex items-center gap-3 text-xs font-bold ${agent.accommodation_included ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-gray-50 border-gray-200 text-gray-400'}`}>
                <HomeIcon className="w-4 h-4" /> Stay Included: {agent.accommodation_included ? 'Yes' : 'No'}
              </div>
              <div className={`p-3.5 rounded-2xl border flex items-center gap-3 text-xs font-bold ${agent.transport_included ? 'bg-emerald-50 border-emerald-200 text-emerald-800' : 'bg-gray-50 border-gray-200 text-gray-400'}`}>
                <Car className="w-4 h-4" /> Transport: {agent.transport_included ? 'Yes' : 'No'}
              </div>
            </div>
          </div>
        </div>

        {/* REVIEWS SECTION */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-extrabold text-gray-900">Traveller Reviews</h2>
            <span className="text-xs font-bold text-amber-500 bg-amber-50 px-3 py-1 rounded-full flex items-center gap-1">
              <Star className="w-3.5 h-3.5 fill-amber-500" /> {agent.rating_avg || 5.0} Average
            </span>
          </div>

          {reviews.length === 0 ? (
            <p className="text-sm font-semibold text-gray-500 text-center py-6">
              No written reviews yet for this guide. Be the first to book and review!
            </p>
          ) : (
            <div className="space-y-4">
              {reviews.map((rev) => (
                <div key={rev.id} className="p-4 bg-gray-50 rounded-2xl space-y-2 border border-gray-100">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-sm text-gray-900">{rev.profiles?.full_name || 'Verified Traveller'}</span>
                    <div className="flex items-center gap-1 text-amber-500 text-xs font-bold">
                      <Star className="w-3.5 h-3.5 fill-amber-500" /> {rev.overall_rating}/5
                    </div>
                  </div>
                  <p className="text-xs text-gray-600 font-medium">{rev.review_text}</p>
                </div>
              ))}
            </div>
          )}
        </div>

      </div>

      {/* STORY VIEWER MODAL */}
      {showStoryViewer && (
        <GuideStoryViewer
          stories={stories}
          agent={agent}
          onClose={() => setShowStoryViewer(false)}
        />
      )}
    </div>
  );
}
