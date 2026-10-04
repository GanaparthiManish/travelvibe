import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { ShieldCheck, Calendar, DollarSign, Star, Check, X, MessageSquare, Clock, Users, AlertCircle, ShieldAlert } from 'lucide-react';
import EscrowTripTimeline from '../../components/EscrowTripTimeline';
import SOSButtonModal from '../../components/SOSButtonModal';

export default function AgentDashboard() {
  const { user, profile, agentDetails } = useAuth();
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sosTargetBooking, setSosTargetBooking] = useState(null);

  const fetchAgentBookings = async () => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const { data } = await supabase
        .from('bookings')
        .select('*, profiles!bookings_traveller_id_fkey(full_name, photo_url, phone)')
        .eq('agent_id', currentUserId)
        .order('created_at', { ascending: false });

      setBookings(data || []);
    } catch (err) {
      console.error('Error fetching agent bookings:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAgentBookings();

    if (!user?.id) return;

    // Real-time subscription to Bookings, Agent Details & Profiles for this Agent
    const channel = supabase
      .channel(`agent_dashboard_rt_${user.id}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bookings',
          filter: `agent_id=eq.${user.id}`,
        },
        () => {
          fetchAgentBookings();
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'agent_details',
          filter: `id=eq.${user.id}`,
        },
        () => {
          refreshProfile(user.id);
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'profiles',
          filter: `id=eq.${user.id}`,
        },
        () => {
          refreshProfile(user.id);
        }
      )
      .subscribe();

    // Instant broadcast listener for immediate admin suspension/unsuspension
    const adminSyncChannel = supabase
      .channel('global_admin_sync')
      .on('broadcast', { event: 'agent_status_changed' }, (payload) => {
        if (payload?.payload?.id === user.id) {
          refreshProfile(user.id);
          fetchAgentBookings();
        }
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
      supabase.removeChannel(adminSyncChannel);
    };
  }, [user]);

  const handleUpdateStatus = async (bookingId, newStatus) => {
    try {
      const { error: updateErr } = await supabase
        .from('bookings')
        .update({ status: newStatus })
        .eq('id', bookingId);

      if (updateErr) throw updateErr;

      // Send notification to traveller
      const booking = bookings.find((b) => b.id === bookingId);
      if (booking?.traveller_id) {
        await supabase.from('notifications').insert({
          user_id: booking.traveller_id,
          type: 'booking_update',
          title: `Booking ${newStatus.toUpperCase()}`,
          body: `Your guide ${profile?.full_name || ''} has ${newStatus} your booking for ${booking.destination}.`,
          related_id: bookingId,
        });
      }

      fetchAgentBookings();
    } catch (err) {
      console.error('Error updating booking status:', err);
      alert('Failed to update booking: ' + err.message);
    }
  };

  const pendingRequests = bookings.filter((b) => b.status === 'pending');
  const confirmedBookings = bookings.filter((b) => b.status === 'confirmed' || b.status === 'completed');
  const totalEarnings = confirmedBookings.reduce((sum, b) => sum + (parseFloat(b.total_price) || 0), 0);

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      
      {/* CONSOLE HEADER */}
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl sm:text-3xl font-extrabold text-gray-900 tracking-tight">Agent Console</h1>
              <span className="px-3 py-1 bg-purple-100 text-[#8B61F1] text-xs font-extrabold uppercase rounded-full">
                Verified Guide
              </span>
            </div>
            <p className="text-sm font-semibold text-gray-500">Welcome back, {profile?.full_name || 'Agent'}</p>
          </div>

          <div className="flex items-center gap-3">
            <Link
              to="/agent/profile"
              className="px-4 py-2.5 bg-white border border-gray-200 text-gray-800 font-bold text-xs rounded-xl hover:bg-gray-50 shadow-xs"
            >
              Edit Profile & Specialties
            </Link>
            <Link
              to="/agent/availability"
              className="px-4 py-2.5 bg-gray-100 text-gray-800 font-bold text-xs rounded-xl hover:bg-gray-200"
            >
              Manage Calendar
            </Link>
            <Link
              to="/agent/earnings"
              className="px-4 py-2.5 bg-[#8B61F1] text-white font-bold text-xs rounded-xl shadow-xs hover:bg-purple-700"
            >
              Payouts & Earnings
            </Link>
          </div>
        </div>
      </section>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
        
        {/* SUSPENSION WARNING BANNER */}
        {(agentDetails?.suspended === true || profile?.suspended === true) && (
          <div className="p-5 rounded-3xl bg-rose-50 border-2 border-rose-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 text-rose-800">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-2xl bg-rose-100 flex items-center justify-center shrink-0">
                <AlertCircle className="w-6 h-6 text-rose-600" />
              </div>
              <div>
                <h3 className="font-extrabold text-sm text-rose-900">Account Suspended by Administration</h3>
                <p className="text-xs text-rose-700 mt-0.5">
                  Your guide account has been temporarily suspended. Your profile is hidden from travellers, and new booking requests are halted. Please contact support@travelvibe.com for assistance.
                </p>
              </div>
            </div>
            <a
              href="mailto:support@travelvibe.com"
              className="px-4 py-2 bg-rose-600 text-white text-xs font-extrabold rounded-xl hover:bg-rose-700 transition-all shrink-0"
            >
              Contact Support
            </a>
          </div>
        )}

        {/* STATS OVERVIEW */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Total Earnings</span>
            <p className="text-2xl font-extrabold text-[#E8741F]">₹{totalEarnings.toLocaleString()}</p>
            <p className="text-xs font-medium text-gray-500">From confirmed trips</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Pending Requests</span>
            <p className="text-2xl font-extrabold text-amber-500">{pendingRequests.length}</p>
            <p className="text-xs font-medium text-gray-500">Requires immediate review</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Total Bookings</span>
            <p className="text-2xl font-extrabold text-gray-900">{bookings.length}</p>
            <p className="text-xs font-medium text-gray-500">All-time booking requests</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-2">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Guide Rating</span>
            <p className="text-2xl font-extrabold text-amber-500 flex items-center gap-1">
              <Star className="w-6 h-6 fill-amber-500" /> {agentDetails?.rating_avg || 5.0}
            </p>
            <p className="text-xs font-medium text-gray-500">Based on traveller reviews</p>
          </div>
        </div>

        {/* PENDING REQUESTS LIVE FEED */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-extrabold text-gray-900 tracking-tight">Pending Trip Requests ({pendingRequests.length})</h2>
            <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full">
              Live Realtime Stream
            </span>
          </div>

          {loading ? (
            <div className="h-32 bg-gray-200 rounded-3xl animate-pulse"></div>
          ) : pendingRequests.length === 0 ? (
            <div className="bg-white rounded-3xl p-8 text-center border border-gray-200 text-gray-500 text-sm font-semibold">
              No pending requests right now. New requests will pop up live here instantly!
            </div>
          ) : (
            <div className="space-y-4">
              {pendingRequests.map((req) => {
                const travellerName = req.profiles?.full_name || 'Traveller';
                const travellerPhoto = req.profiles?.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';

                return (
                  <div
                    key={req.id}
                    className="bg-white rounded-3xl p-6 shadow-md border-2 border-amber-200 flex flex-col md:flex-row items-start md:items-center justify-between gap-6"
                  >
                    <div className="flex items-start gap-4">
                      <img src={travellerPhoto} alt={travellerName} className="w-14 h-14 rounded-2xl object-cover border-2 border-orange-100 shrink-0" />
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <h3 className="font-extrabold text-gray-900 text-base">{travellerName}</h3>
                          <span className="px-2.5 py-0.5 bg-amber-100 text-amber-800 text-[10px] font-extrabold uppercase rounded-full">
                            Pending Approval
                          </span>
                          <span className="px-2 py-0.5 bg-purple-100 text-[#8B61F1] text-[10px] font-extrabold rounded-md flex items-center gap-1">
                            <Users className="w-3 h-3" /> {req.group_size || 1} {req.group_size > 1 ? 'Guests' : 'Guest'}
                          </span>
                        </div>
                        <p className="text-xs font-bold text-gray-700">Destination: {req.destination}</p>
                        <p className="text-xs text-gray-500 font-medium">Dates: {req.start_date} to {req.end_date}</p>
                        <p className="text-xs text-gray-500 font-medium">Meeting Point: {req.meeting_point || 'City Center'}</p>

                        {/* GROUP MEMBER DETAILS */}
                        {Array.isArray(req.group_members) && req.group_members.length > 0 && (
                          <div className="mt-2 p-2.5 bg-gray-50 rounded-xl border border-gray-100 text-xs">
                            <span className="font-extrabold text-gray-700 block mb-1">
                              👥 Additional Guest Details ({req.group_members.length}):
                            </span>
                            <div className="flex flex-wrap gap-2">
                              {req.group_members.map((m, idx) => (
                                <span key={idx} className="px-2 py-1 bg-white rounded-lg border border-gray-200 text-gray-800 font-medium text-[11px]">
                                  {m.name} {m.phone ? `(${m.phone})` : ''}
                                </span>
                              ))}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="flex flex-col md:items-end gap-2 w-full md:w-auto">
                      <p className="text-xl font-extrabold text-[#E8741F]">₹{req.total_price}</p>
                      <div className="flex items-center gap-2 w-full md:w-auto">
                        <button
                          onClick={() => handleUpdateStatus(req.id, 'confirmed')}
                          className="flex-1 md:flex-initial px-5 py-2.5 bg-emerald-600 text-white font-bold text-xs rounded-xl shadow-xs hover:bg-emerald-700 flex items-center justify-center gap-1"
                        >
                          <Check className="w-4 h-4" /> Accept Request
                        </button>
                        <button
                          onClick={() => handleUpdateStatus(req.id, 'cancelled')}
                          className="flex-1 md:flex-initial px-4 py-2.5 bg-rose-50 text-rose-600 font-bold text-xs rounded-xl hover:bg-rose-100 flex items-center justify-center gap-1"
                        >
                          <X className="w-4 h-4" /> Decline
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* ACTIVE GUIDED TRIPS & STAGED ESCROW MILESTONES */}
        {bookings.filter(b => b.status === 'confirmed' || b.status === 'ongoing').length > 0 && (
          <section className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-extrabold text-gray-900 tracking-tight">
                  Active Guided Trips & Escrow Milestones ({bookings.filter(b => b.status === 'confirmed' || b.status === 'ongoing').length})
                </h2>
                <span className="px-2.5 py-0.5 bg-emerald-100 text-emerald-800 text-xs font-bold rounded-full">
                  Protected Escrow
                </span>
              </div>

              <button
                onClick={() => {
                  const activeB = bookings.find(b => b.status === 'confirmed' || b.status === 'ongoing');
                  if (activeB) setSosTargetBooking(activeB);
                }}
                className="px-3.5 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded-xl font-black text-xs flex items-center gap-1.5 shadow-sm transition-all"
              >
                <ShieldAlert className="w-3.5 h-3.5" />
                24/7 SOS
              </button>
            </div>

            <div className="space-y-6">
              {bookings
                .filter(b => b.status === 'confirmed' || b.status === 'ongoing')
                .map((b) => (
                  <div key={b.id} className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-4">
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-gray-100 pb-4">
                      <div>
                        <div className="flex items-center gap-2">
                          <h3 className="text-base font-extrabold text-gray-900">{b.destination}</h3>
                          <span className="px-2.5 py-0.5 bg-emerald-100 text-emerald-800 text-[10px] font-extrabold uppercase rounded-full">
                            {b.status}
                          </span>
                        </div>
                        <p className="text-xs text-gray-500 font-medium">
                          Traveller: <strong className="text-gray-800">{b.profiles?.full_name || 'Traveller'}</strong> • Dates: {b.start_date} to {b.end_date} • Total: <strong className="text-[#E8741F]">₹{b.total_price?.toLocaleString('en-IN')}</strong>
                        </p>
                      </div>

                      <div className="flex items-center gap-2">
                        <Link
                          to={`/chat/${b.id}`}
                          className="px-3 py-1.5 bg-purple-50 text-[#8B61F1] font-bold text-xs rounded-xl hover:bg-purple-100 flex items-center gap-1"
                        >
                          <MessageSquare className="w-3.5 h-3.5" /> Chat
                        </Link>
                        <button
                          onClick={() => setSosTargetBooking(b)}
                          className="px-3 py-1.5 bg-red-600 hover:bg-red-700 text-white font-extrabold text-xs rounded-xl flex items-center gap-1 shadow-xs"
                        >
                          <ShieldAlert className="w-3.5 h-3.5" /> SOS
                        </button>
                      </div>
                    </div>

                    <EscrowTripTimeline
                      booking={b}
                      role="agent"
                      onUpdated={fetchAgentBookings}
                      onOpenSOS={() => setSosTargetBooking(b)}
                    />
                  </div>
                ))}
            </div>
          </section>
        )}

        {/* ALL BOOKINGS TABLE */}
        <section className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-4">
          <h2 className="text-xl font-extrabold text-gray-900 tracking-tight">All Trip History ({bookings.length})</h2>
          
          {bookings.length === 0 ? (
            <p className="text-sm font-semibold text-gray-500 py-4 text-center">No booking records found.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm font-medium text-gray-700">
                <thead className="bg-gray-50 text-xs uppercase font-extrabold text-gray-400 border-b border-gray-100">
                  <tr>
                    <th className="py-3 px-4">Traveller</th>
                    <th className="py-3 px-4">Group</th>
                    <th className="py-3 px-4">Destination</th>
                    <th className="py-3 px-4">Dates</th>
                    <th className="py-3 px-4">Amount</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                  {bookings.map((b) => (
                    <tr key={b.id} className="hover:bg-gray-50/50">
                      <td className="py-3.5 px-4 font-bold text-gray-900">{b.profiles?.full_name || 'Traveller'}</td>
                      <td className="py-3.5 px-4">
                        <span className="font-bold text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded-md">
                          👥 {b.group_size || 1}
                        </span>
                      </td>
                      <td className="py-3.5 px-4">{b.destination}</td>
                      <td className="py-3.5 px-4 text-xs font-semibold text-gray-500">{b.start_date} to {b.end_date}</td>
                      <td className="py-3.5 px-4 font-extrabold text-[#E8741F]">₹{b.total_price}</td>
                      <td className="py-3.5 px-4">
                        <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase ${
                          b.status === 'confirmed' ? 'bg-emerald-100 text-emerald-800' :
                          b.status === 'pending' ? 'bg-amber-100 text-amber-800' :
                          b.status === 'completed' ? 'bg-blue-100 text-blue-800' : 'bg-rose-100 text-rose-800'
                        }`}>
                          {b.status}
                        </span>
                      </td>
                      <td className="py-3.5 px-4">
                        <Link
                          to={`/chat/${b.id}`}
                          className="px-3 py-1.5 bg-purple-50 text-[#8B61F1] font-bold text-xs rounded-lg hover:bg-purple-100 inline-flex items-center gap-1"
                        >
                          <MessageSquare className="w-3.5 h-3.5" /> Chat
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

      </div>

      {/* Emergency SOS Modal for Agent */}
      {sosTargetBooking && (
        <SOSButtonModal
          booking={sosTargetBooking}
          role="agent"
          isOpen={!!sosTargetBooking}
          onClose={() => setSosTargetBooking(null)}
        />
      )}
    </div>
  );
}
