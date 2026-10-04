import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { ShoppingBag, Package, Truck, CheckCircle2, Clock, AlertCircle } from 'lucide-react';

export default function MyOrders() {
  const { user } = useAuth();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchMyOrders = async (silent = false) => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId && !user?.id) {
      if (!silent) setLoading(false);
      return;
    }

    try {
      if (!silent) setLoading(true);
      let ids = [currentUserId || user?.id].filter(Boolean);

      // Also link any profile IDs matching user's email or phone
      if (user?.email || user?.phone) {
        try {
          let q = supabase.from('profiles').select('id');
          if (user.email && user.phone) {
            q = q.or(`email.eq.${user.email},phone.eq.${user.phone}`);
          } else if (user.email) {
            q = q.eq('email', user.email);
          } else if (user.phone) {
            q = q.eq('phone', user.phone);
          }
          const { data: matched } = await q;
          if (matched?.length) {
            ids = Array.from(new Set([...ids, ...matched.map(m => m.id)]));
          }
        } catch (_) {}
      }

      const { data } = await supabase
        .from('orders')
        .select('*')
        .in('traveller_id', ids)
        .order('created_at', { ascending: false });

      setOrders(data || []);
    } catch (err) {
      console.error('Error fetching my orders:', err);
    } finally {
      if (!silent) setLoading(false);
    }
  };

  useEffect(() => {
    fetchMyOrders();

    const channel = supabase
      .channel(`my_orders_realtime_${user?.id || 'guest'}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, () => {
        fetchMyOrders(true);
      })
      .subscribe();

    const bc = supabase
      .channel('order_live_status_channel')
      .on('broadcast', { event: 'order_placed' }, () => fetchMyOrders(true))
      .on('broadcast', { event: 'order_status_updated' }, () => fetchMyOrders(true))
      .subscribe();

    const poll = setInterval(() => fetchMyOrders(true), 3000);
    const onVis = () => { if (document.visibilityState === 'visible') fetchMyOrders(true); };
    document.addEventListener('visibilitychange', onVis);

    return () => {
      clearInterval(poll);
      document.removeEventListener('visibilitychange', onVis);
      supabase.removeChannel(channel);
      supabase.removeChannel(bc);
    };
  }, [user]);

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto space-y-2">
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">My Shop Orders</h1>
          <p className="text-sm font-semibold text-gray-500">Track delivery status for your travel gear purchases in real-time</p>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {loading ? (
          <div className="space-y-4">
            {[1, 2].map((i) => (
              <div key={i} className="h-36 bg-gray-200 rounded-3xl animate-pulse"></div>
            ))}
          </div>
        ) : orders.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-gray-200 space-y-4">
            <Package className="w-12 h-12 text-gray-400 mx-auto" />
            <h3 className="text-lg font-bold text-gray-800">No orders placed yet</h3>
            <p className="text-sm text-gray-500">Explore our travel shop for high quality backpacks and gear!</p>
            <Link to="/shop" className="inline-block px-5 py-2.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl">
              Browse Travel Shop
            </Link>
          </div>
        ) : (
          <div className="space-y-4">
            {orders.map((ord) => {
              const itemsList = Array.isArray(ord.items) ? ord.items : [];
              return (
                <div key={ord.id} className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-4">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-gray-100 pb-3">
                    <div>
                      <span className="text-xs font-bold text-gray-400 uppercase">Order ID: #{ord.id.substring(0, 8)}</span>
                      <p className="text-xs text-gray-500 font-semibold">{new Date(ord.created_at).toLocaleDateString()}</p>
                    </div>
                    <span className="px-3 py-1 bg-purple-50 text-[#8B61F1] text-xs font-extrabold uppercase rounded-full w-fit">
                      Status: {ord.status.replaceAll('_', ' ')}
                    </span>
                  </div>

                  <div className="space-y-2">
                    {itemsList.map((item, idx) => (
                      <div key={idx} className="flex justify-between text-sm font-semibold text-gray-800">
                        <span>{item.name || 'Travel Product'} (x{item.quantity || 1})</span>
                        <span className="font-extrabold text-[#E8741F]">₹{item.price}</span>
                      </div>
                    ))}
                  </div>

                  <div className="pt-3 border-t border-gray-100 flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs text-gray-500 font-semibold">
                    <p className="truncate max-w-md">📍 Shipping to: {ord.delivery_address}</p>
                    <p className="text-base font-extrabold text-gray-900">Total: ₹{ord.total_amount}</p>
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
