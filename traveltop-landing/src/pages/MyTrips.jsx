import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { Calendar, MapPin, MessageSquare, Clock, CheckCircle2, XCircle, AlertCircle, ShieldAlert } from 'lucide-react';
import EscrowTripTimeline from '../components/EscrowTripTimeline';
import SOSButtonModal from '../components/SOSButtonModal';

export default function MyTrips() {
  const { user } = useAuth();
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('all');
  const [sosTargetBooking, setSosTargetBooking] = useState(null);

  const fetchMyBookings = async (silent = false) => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
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
        .from('bookings')
        .select('*, profiles!bookings_agent_id_fkey(full_name, photo_url, phone)')
        .in('traveller_id', ids)
        .order('created_at', { ascending: false });

      setBookings(data || []);
    } catch (err) {
      console.error('Error fetching my trips:', err);
    } finally {
      if (!silent) setLoading(false);
    }
  };

  useEffect(() => {
    fetchMyBookings();

    // Real-time Subscription to Bookings table
    const channel = supabase
      .channel(`my_trips_realtime_${user?.id || 'guest'}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bookings',
        },
        () => {
          fetchMyBookings(true);
        }
      )
      .subscribe();

    const bc = supabase
      .channel('booking_live_status_channel')
      .on('broadcast', { event: 'booking_created' }, () => fetchMyBookings(true))
      .on('broadcast', { event: 'refund_status_updated' }, () => fetchMyBookings(true))
      .subscribe();

    const poll = setInterval(() => fetchMyBookings(true), 3000);
    const onVis = () => { if (document.visibilityState === 'visible') fetchMyBookings(true); };
    document.addEventListener('visibilitychange', onVis);

    return () => {
      clearInterval(poll);
      document.removeEventListener('visibilitychange', onVis);
      supabase.removeChannel(channel);
      supabase.removeChannel(bc);
    };
  }, [user]);

  const handleCancelBooking = async (bookingId) => {
    if (!window.confirm('Are you sure you want to cancel this booking?')) return;
    try {
      await supabase
        .from('bookings')
        .update({ status: 'cancelled' })
        .eq('id', bookingId);
      
      fetchMyBookings();
    } catch (err) {
      console.error('Error cancelling booking:', err);
    }
  };

  const filteredBookings = bookings.filter((b) => {
    if (activeTab === 'all') return true;
    return b.status === activeTab;
  });

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      
      {/* HEADER */}
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">My Trips & Bookings</h1>
              <p className="text-sm font-semibold text-gray-500">Live real-time view of your upcoming and past guided journeys</p>
            </div>

            {/* Quick Emergency Banner if there are active bookings */}
            {bookings.some(b => b.status === 'confirmed' || b.status === 'ongoing') && (
              <button
                onClick={() => {
                  const activeB = bookings.find(b => b.status === 'confirmed' || b.status === 'ongoing') || bookings[0];
                  setSosTargetBooking(activeB);
                }}
                className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-2xl font-black text-xs flex items-center gap-2 shadow-md shadow-red-600/20 animate-pulse transition-all shrink-0"
              >
                <ShieldAlert className="w-4 h-4" />
                24/7 EMERGENCY SOS
              </button>
            )}
          </div>

          {/* TABS */}
          <div className="flex items-center gap-2 pt-4 overflow-x-auto scrollbar-none">
            {['all', 'pending', 'confirmed', 'completed', 'cancelled'].map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`px-4 py-2 rounded-xl text-xs font-extrabold capitalize transition-all border ${
                  activeTab === tab
                    ? 'bg-[#8B61F1] text-white border-[#8B61F1] shadow-xs'
                    : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
                }`}
              >
                {tab} ({bookings.filter((b) => tab === 'all' || b.status === tab).length})
              </button>
            ))}
          </div>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {loading ? (
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-40 bg-gray-200 rounded-3xl animate-pulse"></div>
            ))}
          </div>
        ) : filteredBookings.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-gray-200 space-y-4">
            <Calendar className="w-12 h-12 text-gray-400 mx-auto" />
            <h3 className="text-lg font-bold text-gray-800">No {activeTab} trips found</h3>
            <p className="text-sm text-gray-500">Book your first local guide and start exploring!</p>
            <Link to="/app" className="inline-block px-5 py-2.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl">
              Explore Destinations
            </Link>
          </div>
        ) : (
          <div className="space-y-6">
            {filteredBookings.map((b) => {
              const agentName = b.profiles?.full_name || 'Local Guide';
              const agentPhoto = b.profiles?.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';

              return (
                <div
                  key={b.id}
                  className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-5 hover:shadow-md transition-all"
                >
                  <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
                    <div className="flex items-start gap-4">
                      <img src={agentPhoto} alt={agentName} className="w-16 h-16 rounded-2xl object-cover border-2 border-orange-100 shrink-0" />
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <h3 className="font-extrabold text-gray-900 text-lg">{b.destination}</h3>
                          <span
                            className={`px-3 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider ${
                              b.status === 'confirmed'
                                ? 'bg-emerald-100 text-emerald-700'
                                : b.status === 'pending'
                                ? 'bg-amber-100 text-amber-700'
                                : b.status === 'completed'
                                ? 'bg-blue-100 text-blue-700'
                                : 'bg-rose-100 text-rose-700'
                            }`}
                          >
                            {b.status}
                          </span>
                        </div>

                        <p className="text-xs font-semibold text-gray-600">
                          Guide: <span className="text-gray-900 font-bold">{agentName}</span>
                        </p>

                        <div className="flex flex-wrap items-center gap-4 text-xs font-medium text-gray-500 pt-1">
                          <span className="flex items-center gap-1">
                            <Calendar className="w-3.5 h-3.5 text-[#E8741F]" /> {b.start_date} to {b.end_date}
                          </span>
                          <span>•</span>
                          <span className="font-bold text-gray-900">Total: ₹{b.total_price?.toLocaleString('en-IN')}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-3 w-full md:w-auto border-t md:border-t-0 pt-4 md:pt-0 border-gray-100">
                      <Link
                        to={`/chat/${b.id}`}
                        className="flex-1 md:flex-initial px-4 py-2.5 bg-purple-50 text-[#8B61F1] font-bold text-xs rounded-xl hover:bg-purple-100 flex items-center justify-center gap-2 transition-all"
                      >
                        <MessageSquare className="w-4 h-4" /> Live Chat
                      </Link>

                      {(b.status === 'confirmed' || b.status === 'ongoing') && (
                        <button
                          onClick={() => setSosTargetBooking(b)}
                          className="px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white font-extrabold text-xs rounded-xl flex items-center gap-1.5 shadow-sm transition-all"
                        >
                          <ShieldAlert className="w-4 h-4" /> SOS
                        </button>
                      )}

                      {b.status === 'pending' && (
                        <button
                          onClick={() => handleCancelBooking(b.id)}
                          className="px-4 py-2.5 bg-rose-50 text-rose-600 font-bold text-xs rounded-xl hover:bg-rose-100 transition-all"
                        >
                          Cancel
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Staged Escrow Timeline & Milestones for Confirmed/Ongoing/Completed bookings */}
                  {(b.status === 'confirmed' || b.status === 'ongoing' || b.status === 'completed') && (
                    <div className="border-t border-gray-100 pt-4">
                      <EscrowTripTimeline
                        booking={b}
                        role="traveller"
                        onUpdated={fetchMyBookings}
                        onOpenSOS={() => setSosTargetBooking(b)}
                      />
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Emergency SOS Modal */}
      {sosTargetBooking && (
        <SOSButtonModal
          booking={sosTargetBooking}
          role="traveller"
          isOpen={!!sosTargetBooking}
          onClose={() => setSosTargetBooking(null)}
        />
      )}
    </div>
  );
}
