import React, { useState, useEffect, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { useWishlist } from '../context/WishlistContext';
import { Heart, Star, ShieldCheck, Trash2, MapPin, ShoppingBag, UserCheck, ArrowRight } from 'lucide-react';

export default function Wishlist() {
  const { user } = useAuth();
  const { removeWishlistItem, refreshWishlist } = useWishlist();
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState('all'); // 'all', 'places', 'gear', 'guides'
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchFullWishlist = useCallback(async () => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) {
      setItems([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      // 1. Strictly fetch only rows belonging to the authenticated user
      const { data: rawWishlist, error: wlErr } = await supabase
        .from('wishlists')
        .select('*')
        .eq('traveller_id', currentUserId)
        .order('created_at', { ascending: false });

      if (wlErr) throw wlErr;

      const wishlistRows = rawWishlist || [];
      if (wishlistRows.length === 0) {
        setItems([]);
        return;
      }

      // Collect IDs
      const agentIds = wishlistRows.map((r) => r.agent_id).filter(Boolean);
      const destIds = wishlistRows.map((r) => r.destination_id).filter(Boolean);
      const productIds = wishlistRows.map((r) => r.product_id).filter(Boolean);

      // 2. Fetch Agents details
      let agentMap = {};
      if (agentIds.length > 0) {
        const { data: agData } = await supabase
          .from('agent_details')
          .select('*, profiles!inner(full_name, photo_url, phone, suspended)')
          .in('id', agentIds);
        (agData || []).forEach((ag) => {
          agentMap[ag.id] = ag;
        });
      }

      // 3. Fetch Destinations details
      let destMap = {};
      if (destIds.length > 0) {
        const { data: destData } = await supabase
          .from('destinations')
          .select('*')
          .in('id', destIds);
        (destData || []).forEach((d) => {
          destMap[d.id] = d;
        });
      }

      // 4. Fetch Products details
      let prodMap = {};
      if (productIds.length > 0) {
        const { data: prodData } = await supabase
          .from('products')
          .select('*')
          .in('id', productIds);
        (prodData || []).forEach((p) => {
          prodMap[p.id] = p;
        });
      }

      // 5. Combine into normalized items
      const combined = wishlistRows
        .map((row) => {
          if (row.agent_id) {
            const ag = agentMap[row.agent_id];
            return {
              wishlistId: row.id,
              type: 'guide',
              id: row.agent_id,
              title: ag?.profiles?.full_name || 'Verified Local Guide',
              image:
                ag?.profiles?.photo_url ||
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
              subtitle: Array.isArray(ag?.places_covered)
                ? ag.places_covered.join(', ')
                : 'Local Experience Guide',
              rating: ag?.rating_avg || 5.0,
              price: ag?.price_per_day ? `₹${ag.price_per_day}/day` : '₹1,500/day',
              link: `/agents/${row.agent_id}`,
              actionLink: `/book/${row.agent_id}`,
              actionText: 'Book Guide',
            };
          } else if (row.destination_id) {
            const d = destMap[row.destination_id];
            return {
              wishlistId: row.id,
              type: 'place',
              id: row.destination_id,
              title: d?.name || 'Scenic Destination',
              image:
                d?.image_url ||
                'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=600&q=80',
              subtitle: d?.country || 'India',
              rating: d?.rating || 4.9,
              price: d?.best_season ? `Best: ${d.best_season}` : 'Year-round',
              link: `/destinations/${row.destination_id}`,
              actionLink: `/destinations/${row.destination_id}`,
              actionText: 'Explore Place',
            };
          } else if (row.product_id) {
            const p = prodMap[row.product_id];
            return {
              wishlistId: row.id,
              type: 'gear',
              id: row.product_id,
              title: p?.name || 'Travel Essential',
              image:
                p?.image_url ||
                'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=400&q=80',
              subtitle: p?.category || 'Gear & Accessories',
              rating: p?.rating || 4.8,
              price: p?.price ? `₹${p.price}` : '₹999',
              link: `/shop/${row.product_id}`,
              actionLink: `/shop/${row.product_id}`,
              actionText: 'View Product',
            };
          }
          return null;
        })
        .filter(Boolean);

      setItems(combined);
    } catch (err) {
      console.error('Error fetching full wishlist:', err);
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    fetchFullWishlist();
  }, [fetchFullWishlist]);

  const handleRemove = async (wishlistId) => {
    setItems((prev) => prev.filter((item) => item.wishlistId !== wishlistId));
    await removeWishlistItem(wishlistId);
  };

  const filteredItems = items.filter((item) => {
    if (activeTab === 'all') return true;
    if (activeTab === 'places') return item.type === 'place';
    if (activeTab === 'gear') return item.type === 'gear';
    if (activeTab === 'guides') return item.type === 'guide';
    return true;
  });

  const placesCount = items.filter((i) => i.type === 'place').length;
  const gearCount = items.filter((i) => i.type === 'gear').length;
  const guidesCount = items.filter((i) => i.type === 'guide').length;

  if (!user) {
    return (
      <div className="pb-16 bg-[#F7F6FB] min-h-screen flex items-center justify-center p-4">
        <div className="bg-white rounded-3xl p-10 max-w-md w-full text-center shadow-sm border border-gray-100 space-y-4">
          <div className="w-16 h-16 bg-rose-50 text-rose-500 rounded-full flex items-center justify-center mx-auto">
            <Heart className="w-8 h-8 fill-rose-500" />
          </div>
          <h2 className="text-2xl font-black text-gray-900">Sign in for Your Wishlist</h2>
          <p className="text-sm font-medium text-gray-500">
            Keep track of your favorite places, gear, and local guides across all your devices.
          </p>
          <div className="pt-2 flex flex-col gap-3">
            <Link
              to="/login"
              className="w-full py-3 bg-[#E8741F] text-white font-bold text-sm rounded-xl shadow-xs hover:bg-[#D66311] transition-all"
            >
              Sign In
            </Link>
            <Link
              to="/signup"
              className="w-full py-3 bg-gray-50 text-gray-700 font-bold text-sm rounded-xl hover:bg-gray-100 transition-all"
            >
              Create Free Account
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      {/* Header section */}
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto space-y-4">
          <div>
            <h1 className="text-3xl font-black text-gray-900 tracking-tight">Saved Wishlist</h1>
            <p className="text-sm font-semibold text-gray-500">
              Strictly saved for your account ({user.email}). Zero leakage.
            </p>
          </div>

          {/* Filter Tabs matching Flutter Mobile App */}
          <div className="flex items-center gap-2 overflow-x-auto pb-1 no-scrollbar">
            <button
              onClick={() => setActiveTab('all')}
              className={`px-4 py-2 rounded-xl font-bold text-xs transition-all flex items-center gap-1.5 ${
                activeTab === 'all'
                  ? 'bg-gray-900 text-white shadow-xs'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              All Items
              <span className="ml-1 px-1.5 py-0.5 rounded-full text-[10px] bg-white/20">
                {items.length}
              </span>
            </button>
            <button
              onClick={() => setActiveTab('places')}
              className={`px-4 py-2 rounded-xl font-bold text-xs transition-all flex items-center gap-1.5 ${
                activeTab === 'places'
                  ? 'bg-[#E8741F] text-white shadow-xs'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              <MapPin className="w-3.5 h-3.5" />
              Places
              <span className="ml-1 px-1.5 py-0.5 rounded-full text-[10px] bg-white/20">
                {placesCount}
              </span>
            </button>
            <button
              onClick={() => setActiveTab('gear')}
              className={`px-4 py-2 rounded-xl font-bold text-xs transition-all flex items-center gap-1.5 ${
                activeTab === 'gear'
                  ? 'bg-purple-600 text-white shadow-xs'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              <ShoppingBag className="w-3.5 h-3.5" />
              Gear
              <span className="ml-1 px-1.5 py-0.5 rounded-full text-[10px] bg-white/20">
                {gearCount}
              </span>
            </button>
            <button
              onClick={() => setActiveTab('guides')}
              className={`px-4 py-2 rounded-xl font-bold text-xs transition-all flex items-center gap-1.5 ${
                activeTab === 'guides'
                  ? 'bg-blue-600 text-white shadow-xs'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              <UserCheck className="w-3.5 h-3.5" />
              Guides
              <span className="ml-1 px-1.5 py-0.5 rounded-full text-[10px] bg-white/20">
                {guidesCount}
              </span>
            </button>
          </div>
        </div>
      </section>

      {/* Content grid */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} className="h-64 bg-gray-200 rounded-3xl animate-pulse"></div>
            ))}
          </div>
        ) : filteredItems.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-gray-200 space-y-4 max-w-lg mx-auto">
            <div className="w-16 h-16 bg-rose-50 text-rose-400 rounded-full flex items-center justify-center mx-auto">
              <Heart className="w-8 h-8" />
            </div>
            <h3 className="text-xl font-bold text-gray-800">No saved {activeTab} yet</h3>
            <p className="text-sm text-gray-500 font-medium">
              Tap the heart icon anywhere across the site to save destinations, shop gear, and local guides!
            </p>
            <div className="flex flex-wrap gap-2 justify-center pt-2">
              <Link
                to="/app"
                className="px-4 py-2 bg-gray-900 text-white font-bold text-xs rounded-xl hover:bg-gray-800"
              >
                Explore Places
              </Link>
              <Link
                to="/shop"
                className="px-4 py-2 bg-purple-600 text-white font-bold text-xs rounded-xl hover:bg-purple-700"
              >
                Travel Shop
              </Link>
              <Link
                to="/agents"
                className="px-4 py-2 bg-[#E8741F] text-white font-bold text-xs rounded-xl hover:bg-[#D66311]"
              >
                Find Guides
              </Link>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {filteredItems.map((item) => (
              <div
                key={item.wishlistId}
                className="bg-white rounded-3xl overflow-hidden shadow-xs hover:shadow-md transition-shadow border border-gray-100 flex flex-col justify-between group"
              >
                <div>
                  <div className="relative h-48 overflow-hidden bg-gray-100">
                    <img
                      src={item.image}
                      alt={item.title}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                    <div className="absolute top-3 left-3">
                      <span
                        className={`text-[10px] font-black uppercase tracking-wider px-2.5 py-1 rounded-full text-white shadow-xs ${
                          item.type === 'place'
                            ? 'bg-amber-500'
                            : item.type === 'gear'
                            ? 'bg-purple-600'
                            : 'bg-blue-600'
                        }`}
                      >
                        {item.type}
                      </span>
                    </div>
                    <button
                      onClick={() => handleRemove(item.wishlistId)}
                      className="absolute top-3 right-3 p-2 bg-white/90 hover:bg-white text-gray-500 hover:text-rose-500 rounded-full shadow-sm transition-colors"
                      title="Remove from wishlist"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>

                  <div className="p-5 space-y-2">
                    <div className="flex items-start justify-between gap-2">
                      <Link
                        to={item.link}
                        className="font-extrabold text-base text-gray-900 hover:text-[#E8741F] transition-colors line-clamp-1"
                      >
                        {item.title}
                      </Link>
                      {item.type === 'guide' && (
                        <ShieldCheck className="w-4 h-4 text-emerald-500 shrink-0 mt-0.5" />
                      )}
                    </div>

                    <p className="text-xs font-semibold text-gray-500 line-clamp-1">
                      {item.subtitle}
                    </p>

                    <div className="flex items-center justify-between text-xs font-bold pt-1">
                      <span className="flex items-center gap-1 text-amber-500">
                        <Star className="w-3.5 h-3.5 fill-amber-500" />
                        {item.rating}
                      </span>
                      <span className="text-gray-900 font-extrabold">{item.price}</span>
                    </div>
                  </div>
                </div>

                <div className="p-5 pt-0 border-t border-gray-50 mt-2 flex items-center justify-between gap-3">
                  <Link
                    to={item.link}
                    className="text-xs font-bold text-gray-500 hover:text-gray-900 transition-colors"
                  >
                    Details
                  </Link>
                  <Link
                    to={item.actionLink}
                    className="px-4 py-2 bg-[#E8741F] hover:bg-[#D66311] text-white font-bold text-xs rounded-xl shadow-xs transition-colors flex items-center gap-1"
                  >
                    {item.actionText}
                    <ArrowRight className="w-3 h-3" />
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
