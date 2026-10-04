import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { ShoppingBag, Star, ArrowLeft, CheckCircle2, Truck, ShieldCheck, AlertCircle } from 'lucide-react';
import WishlistHeartButton from '../components/WishlistHeartButton';

export default function ProductDetail() {
  const { productId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [address, setAddress] = useState('');
  const [ordering, setOrdering] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetchProduct() {
      try {
        setLoading(true);
        const { data } = await supabase
          .from('products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

        setProduct(data);
      } catch (err) {
        console.error('Error fetching product:', err);
      } finally {
        setLoading(false);
      }
    }
    fetchProduct();
  }, [productId]);

  const handlePlaceOrder = async (e) => {
    e.preventDefault();

    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      setError('Please log in to place an order.');
      return;
    }

    if (!address.trim()) {
      setError('Please enter a delivery address.');
      return;
    }

    setOrdering(true);
    setError(null);

    try {
      const itemsPayload = [
        {
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: 1,
        },
      ];

      const { data: order, error: orderErr } = await supabase
        .from('orders')
        .insert({
          traveller_id: currentUserId,
          items: itemsPayload,
          total_amount: product.price,
          delivery_address: address.trim(),
          status: 'placed',
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (orderErr) throw orderErr;

      // Broadcast order placed event in realtime
      try {
        const ch = supabase.channel('order_live_status_channel');
        await ch.subscribe();
        await ch.send({
          type: 'broadcast',
          event: 'order_placed',
          payload: order,
        });

        const syncCh = supabase.channel('global_admin_sync');
        await syncCh.subscribe();
        await syncCh.send({
          type: 'broadcast',
          event: 'order_placed',
          payload: order,
        });
      } catch (bcErr) {
        console.warn('Realtime order broadcast notice:', bcErr);
      }

      navigate('/my-orders');
    } catch (err) {
      console.error('Order creation error:', err);
      setError(err.message || 'Failed to place order.');
    } finally {
      setOrdering(false);
    }
  };

  if (loading) {
    return (
      <div className="max-w-4xl mx-auto px-4 py-12 animate-pulse space-y-6">
        <div className="h-80 bg-gray-200 rounded-3xl"></div>
      </div>
    );
  }

  if (!product) {
    return (
      <div className="max-w-md mx-auto my-16 p-8 bg-white rounded-3xl text-center border border-gray-200 space-y-4">
        <ShoppingBag className="w-12 h-12 text-gray-400 mx-auto" />
        <h2 className="text-xl font-bold text-gray-800">Product Not Found</h2>
        <Link to="/shop" className="inline-block px-5 py-2.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl">
          Back to Shop
        </Link>
      </div>
    );
  }

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      <div className="bg-white border-b border-gray-100 py-4 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <Link to="/shop" className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900">
            <ArrowLeft className="w-4 h-4" /> Back to Travel Shop
          </Link>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-xl border border-gray-100 grid grid-cols-1 md:grid-cols-2 gap-8">
          
          {/* IMAGE */}
          <div className="rounded-2xl overflow-hidden bg-gray-100 h-80 relative group">
            <img src={product.image_url || 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62'} alt={product.name} className="w-full h-full object-cover" />
            <div className="absolute top-3 right-3 z-10">
              <WishlistHeartButton type="product" id={product.id} size={20} className="bg-white/90 shadow-md hover:bg-white" />
            </div>
          </div>

          {/* DETAILS & CHECKOUT */}
          <div className="space-y-6 flex flex-col justify-between">
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="px-3 py-1 bg-orange-50 text-[#E8741F] text-xs font-extrabold rounded-full">In Stock ({product.stock || 50})</span>
                <span className="flex items-center gap-1 text-amber-500 font-bold text-xs">
                  <Star className="w-4 h-4 fill-amber-500" /> {product.rating || 4.8} / 5
                </span>
              </div>

              <h1 className="text-2xl font-extrabold text-gray-900">{product.name}</h1>
              <p className="text-sm text-gray-600 font-medium leading-relaxed">{product.description}</p>
              
              <div className="text-3xl font-extrabold text-[#E8741F] pt-2">₹{product.price}</div>
            </div>

            {/* ERROR ALERT */}
            {error && (
              <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-semibold flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <div>{error}</div>
              </div>
            )}

            {/* ORDER FORM */}
            <form onSubmit={handlePlaceOrder} className="space-y-4 pt-4 border-t border-gray-100">
              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Delivery Address</label>
                <textarea
                  required
                  rows={2}
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  placeholder="Enter full shipping address with pincode..."
                  className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-sm font-medium focus:outline-none focus:border-[#E8741F]"
                />
              </div>

              <button
                type="submit"
                disabled={ordering}
                className="w-full py-3.5 bg-[#E8741F] text-white font-extrabold text-sm rounded-xl shadow-md hover:bg-[#D66311] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {ordering ? 'Placing Order...' : `Buy Now (₹${product.price})`}
              </button>
            </form>
          </div>

        </div>
      </div>
    </div>
  );
}
