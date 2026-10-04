import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { ShoppingBag, Star, Package, ArrowRight } from 'lucide-react';
import WishlistHeartButton from '../components/WishlistHeartButton';

export default function Shop() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const { data } = await supabase.from('products').select('*');
      setProducts(data || []);
    } catch (err) {
      console.error('Error fetching shop products:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProducts();

    const sub = supabase
      .channel('shop_products_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, () => {
        fetchProducts();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(sub);
    };
  }, []);

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      
      {/* HEADER */}
      <section className="bg-[#222222] text-white py-12 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto space-y-3">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-extrabold text-orange-400 uppercase tracking-wider">
            <ShoppingBag className="w-4 h-4" /> Travel Vibe Essentials
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight">Travel Gear & Merchandise</h1>
          <p className="text-sm text-gray-300 max-w-xl font-medium">
            High quality backpacks, trekking bottles, hoodies & adventure essentials tested by local guides.
          </p>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-6">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="h-64 bg-gray-200 rounded-3xl animate-pulse"></div>
            ))}
          </div>
        ) : products.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-gray-200 space-y-3">
            <Package className="w-12 h-12 text-gray-400 mx-auto" />
            <h3 className="text-lg font-bold text-gray-800">No products available currently</h3>
            <p className="text-sm text-gray-500">Check back soon for new gear arrivals!</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {products.map((prod) => (
              <Link
                key={prod.id}
                to={`/shop/${prod.id}`}
                className="bg-white rounded-3xl overflow-hidden shadow-sm border border-gray-100 hover:shadow-lg transition-all flex flex-col justify-between group"
              >
                <div>
                  <div className="h-48 bg-gray-100 overflow-hidden relative">
                    <img
                      src={prod.image_url || 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62'}
                      alt={prod.name}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                    <div className="absolute top-3 left-3 px-2.5 py-1 bg-white/90 backdrop-blur-md rounded-full text-xs font-bold text-amber-500 flex items-center gap-1">
                      <Star className="w-3.5 h-3.5 fill-amber-500" /> {prod.rating || 4.8}
                    </div>
                    <div className="absolute top-3 right-3 z-10">
                      <WishlistHeartButton type="product" id={prod.id} size={16} />
                    </div>
                  </div>

                  <div className="p-5 space-y-2">
                    <h3 className="font-extrabold text-gray-900 text-base group-hover:text-[#E8741F] transition-colors">{prod.name}</h3>
                    <p className="text-xs text-gray-500 line-clamp-2">{prod.description}</p>
                  </div>
                </div>

                <div className="p-5 pt-0 flex items-center justify-between border-t border-gray-50 mt-2">
                  <span className="text-lg font-extrabold text-gray-900">₹{prod.price}</span>
                  <span className="px-3 py-1.5 bg-orange-50 text-[#E8741F] font-bold text-xs rounded-xl flex items-center gap-1 group-hover:bg-[#E8741F] group-hover:text-white transition-all">
                    View Details <ArrowRight className="w-3.5 h-3.5" />
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
