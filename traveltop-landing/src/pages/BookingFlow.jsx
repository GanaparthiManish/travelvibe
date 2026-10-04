import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import {
  Calendar,
  MapPin,
  ShieldCheck,
  CreditCard,
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Users,
  Plus,
  Minus,
  Gift,
  Tag,
  Sparkles,
  DollarSign,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';

export default function BookingFlow() {
  const { agentId } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();

  const [agent, setAgent] = useState(null);
  const [destination, setDestination] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [meetingPoint, setMeetingPoint] = useState('');
  const [tripPlan, setTripPlan] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState(null);
  const [blockedDates, setBlockedDates] = useState([]);

  // Feature 3: Group Booking
  const [groupSize, setGroupSize] = useState(1);
  const [groupMembers, setGroupMembers] = useState([]);
  const [showMemberForm, setShowMemberForm] = useState(false);

  // Add-ons
  const [addons, setAddons] = useState([]);
  const [selectedAddonIds, setSelectedAddonIds] = useState([]);

  // Feature 4: Loyalty Rewards & Coupons
  const [loyaltyRewards, setLoyaltyRewards] = useState([]);
  const [selectedRewardId, setSelectedRewardId] = useState(null);
  const [hasPriorCompletedBooking, setHasPriorCompletedBooking] = useState(false);

  // Coupon / Promo Code
  const [couponCode, setCouponCode] = useState('');
  const [appliedCoupon, setAppliedCoupon] = useState(null);
  const [couponDiscountAmount, setCouponDiscountAmount] = useState(0);
  const [couponMsg, setCouponMsg] = useState({ text: '', isError: false });

  // Simplified Payment: Informational Estimated Daily Expenses
  const [customDailyExpenses, setCustomDailyExpenses] = useState(1500);

  useEffect(() => {
    async function loadData() {
      try {
        setLoading(true);

        // 1. Fetch Agent
        const { data: ag } = await supabase
          .from('agent_details')
          .select('*, profiles!inner(full_name, photo_url, phone, suspended)')
          .eq('id', agentId)
          .maybeSingle();

        if (ag && (ag.suspended === true || ag.profiles?.suspended === true)) {
          setError('This guide is currently suspended or unavailable for bookings.');
          setAgent(null);
          return;
        }

        setAgent(ag);
        if (ag?.estimated_daily_expenses) {
          setCustomDailyExpenses(ag.estimated_daily_expenses);
        }

        if (ag && Array.isArray(ag.places_covered) && ag.places_covered.length > 0) {
          setDestination(ag.places_covered[0]);
        } else {
          setDestination('Local Tour');
        }

        // 2. Fetch blocked dates
        const { data: avail } = await supabase
          .from('availability')
          .select('date')
          .eq('agent_id', agentId)
          .or('is_available.eq.false,is_blocked.eq.true');

        if (avail) {
          setBlockedDates(avail.map((a) => a.date));
        }

        // 3. Fetch Agent Addons
        try {
          const { data: addonsData } = await supabase
            .from('agent_addons')
            .select('*')
            .eq('agent_id', agentId)
            .eq('is_active', true);
          setAddons(addonsData || []);
        } catch (_) {}

        // 4. Fetch Traveller's Loyalty Rewards & Repeat Status
        const currentUserId = await getFreshUserId();
        if (currentUserId) {
          try {
            const { data: rewards } = await supabase
              .from('loyalty_rewards')
              .select('*')
              .eq('traveller_id', currentUserId)
              .eq('is_used', false)
              .order('created_at', { ascending: false });

            setLoyaltyRewards(rewards || []);

            // Check if traveller has a prior completed booking with this agent
            const { data: pastBookings } = await supabase
              .from('bookings')
              .select('id')
              .eq('traveller_id', currentUserId)
              .eq('agent_id', agentId)
              .eq('status', 'completed')
              .limit(1);

            if (pastBookings && pastBookings.length > 0) {
              setHasPriorCompletedBooking(true);
            }
          } catch (_) {}
        }
      } catch (err) {
        console.error('Error loading booking data:', err);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, [agentId]);

  // Adjust group member input slots when groupSize changes
  const handleGroupSizeChange = (newSize) => {
    if (newSize < 1 || newSize > 25) return;
    setGroupSize(newSize);

    const neededMembers = newSize - 1;
    setGroupMembers((prev) => {
      const updated = [...prev];
      if (updated.length < neededMembers) {
        for (let i = updated.length; i < neededMembers; i++) {
          updated.push({ name: '', phone: '' });
        }
      } else if (updated.length > neededMembers) {
        updated.splice(neededMembers);
      }
      return updated;
    });

    if (newSize > 1) {
      setShowMemberForm(true);
    }
  };

  const handleMemberChange = (index, field, value) => {
    setGroupMembers((prev) => {
      const updated = [...prev];
      updated[index] = { ...updated[index], [field]: value };
      return updated;
    });
  };

  const toggleAddon = (addonId) => {
    if (selectedAddonIds.includes(addonId)) {
      setSelectedAddonIds(selectedAddonIds.filter((id) => id !== addonId));
    } else {
      setSelectedAddonIds([...selectedAddonIds, addonId]);
    }
  };

  // Pricing calculations
  const calculateDays = () => {
    if (!startDate || !endDate) return 0;
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffTime = end.getTime() - start.getTime();
    if (diffTime < 0) return 0;
    return Math.ceil(diffTime / (1000 * 3600 * 24)) + 1;
  };

  const days = calculateDays();
  const baseRate = agent?.price_per_day || 1500;
  const baseGuideTotal = days * baseRate;

  // Addons total (checking per_person boolean)
  const addonsTotal = addons
    .filter((a) => selectedAddonIds.includes(a.id))
    .reduce((sum, a) => {
      const addonPrice = Number(a.price) || 0;
      return sum + (a.per_person ? addonPrice * groupSize : addonPrice);
    }, 0);

  const subtotal = baseGuideTotal + addonsTotal;

  const handleApplyCoupon = async (e) => {
    e.preventDefault();
    const code = couponCode.trim().toUpperCase();
    if (!code) return;

    setCouponMsg({ text: '', isError: false });

    try {
      const { data: cp } = await supabase
        .from('coupons')
        .select('*')
        .eq('code', code)
        .eq('is_active', true)
        .maybeSingle();

      if (cp) {
        const val = Number(cp.discount_value) || 0;
        const minSpend = Number(cp.min_spend) || 0;
        if (subtotal < minSpend) {
          setCouponMsg({ text: `Minimum spend of ₹${minSpend} required for code ${code}`, isError: true });
          return;
        }

        let disc = 0;
        if (cp.discount_type === 'percent') {
          disc = Math.round((subtotal * val) / 100);
        } else {
          disc = val;
        }

        setAppliedCoupon(cp);
        setCouponDiscountAmount(disc);
        setCouponMsg({ text: `Coupon "${code}" applied! You saved ₹${disc}`, isError: false });
      } else if (code.startsWith('REF-')) {
        const disc = Math.round((subtotal * 10) / 100);
        setAppliedCoupon({ code, description: '10% Referral Discount' });
        setCouponDiscountAmount(disc);
        setCouponMsg({ text: `Referral code "${code}" applied! 10% OFF (-₹${disc})`, isError: false });
      } else {
        setCouponMsg({ text: 'Invalid or expired promo code', isError: true });
      }
    } catch (_) {
      setCouponMsg({ text: 'Error applying coupon code', isError: true });
    }
  };

  // Selected reward discount
  const activeReward = loyaltyRewards.find((r) => r.id === selectedRewardId);
  const discountPercent = activeReward?.discount_percent || 0;
  const rewardDiscountAmount = Math.round((subtotal * discountPercent) / 100);
  const totalDiscount = rewardDiscountAmount + couponDiscountAmount;
  const finalTotal = Math.max(0, subtotal - totalDiscount);

  const handleCreateBooking = async (e) => {
    e.preventDefault();

    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      setError('Please log in to complete your booking.');
      return;
    }

    if (!startDate || !endDate) {
      setError('Please select valid start and end dates.');
      return;
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    if (end < start) {
      setError('End date cannot be before start date.');
      return;
    }

    if (finalTotal <= 0 && days <= 0) {
      setError('Invalid date selection.');
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      // 1. Filter out empty group member entries
      const sanitizedMembers = groupMembers.filter(
        (m) => m.name.trim() || m.phone.trim()
      );

      // 2. Insert Booking with group_size & group_members
      const { data: booking, error: bookErr } = await supabase
        .from('bookings')
        .insert({
          traveller_id: currentUserId,
          agent_id: agentId,
          destination: destination.trim() || 'Local Tour',
          start_date: startDate,
          end_date: endDate,
          total_price: finalTotal,
          guide_fee_total: finalTotal,
          estimated_daily_expenses: Number(customDailyExpenses) || 1500,
          payout_start_released: false,
          payout_final_released: false,
          status: 'pending',
          group_size: groupSize,
          group_members: sanitizedMembers,
          meeting_point: meetingPoint.trim() || 'City Center / Airport',
          trip_plan: tripPlan.trim() || 'Custom Local Sightseeing & Cultural Tour',
          created_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (bookErr) throw bookErr;

      // 3. Mark Loyalty Reward as used (if applied)
      if (activeReward) {
        await supabase
          .from('loyalty_rewards')
          .update({
            is_used: true,
            related_booking_id: booking.id,
          })
          .eq('id', activeReward.id);
      }

      // 4. Repeat booking loyalty reward check:
      // If user had a prior completed booking with this agent, reward them for repeating!
      if (hasPriorCompletedBooking) {
        try {
          await supabase.from('loyalty_rewards').insert({
            traveller_id: currentUserId,
            reward_type: 'repeat_booking',
            description: `5% Repeat Booking Loyalty Reward with ${agent?.profiles?.full_name || 'Guide'}`,
            discount_percent: 5,
            is_used: false,
            related_booking_id: booking.id,
          });
        } catch (_) {}
      }

      // 5. Notify Guide
      await supabase.from('notifications').insert({
        user_id: agentId,
        type: 'booking_request',
        title: `New Booking Request (${groupSize} ${groupSize > 1 ? 'Travellers' : 'Traveller'})!`,
        body: `${user?.user_metadata?.full_name || 'A traveller'} booked ${destination} for ${days} days (${groupSize} guests).`,
        related_id: booking.id,
      });

      // 6. Broadcast booking created in realtime for Admin Console and Guide
      try {
        const bc = supabase.channel('booking_live_status_channel');
        await bc.subscribe();
        await bc.send({
          type: 'broadcast',
          event: 'booking_created',
          payload: booking,
        });

        const syncBc = supabase.channel('global_admin_sync');
        await syncBc.subscribe();
        await syncBc.send({
          type: 'broadcast',
          event: 'booking_created',
          payload: booking,
        });
      } catch (bcErr) {
        console.warn('Realtime booking broadcast notice:', bcErr);
      }

      // 7. Redirect to My Trips
      navigate('/my-trips');
    } catch (err) {
      console.error('Booking creation error:', err);
      setError(err.message || 'Failed to create booking. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="max-w-2xl mx-auto px-4 py-12 space-y-6 animate-pulse">
        <div className="h-40 bg-gray-200 rounded-3xl"></div>
        <div className="h-64 bg-gray-200 rounded-3xl"></div>
      </div>
    );
  }

  if (!agent) {
    return (
      <div className="max-w-md mx-auto my-16 p-8 bg-white rounded-3xl text-center border border-gray-200 space-y-4">
        <AlertCircle className="w-12 h-12 text-rose-500 mx-auto" />
        <h2 className="text-xl font-bold text-gray-800">Agent Unavailable</h2>
        <p className="text-sm text-gray-500">The guide you are trying to book is not available.</p>
        <Link to="/agents" className="inline-block px-5 py-2.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl">
          Back to Guides
        </Link>
      </div>
    );
  }

  const name = agent.profiles?.full_name || 'Local Guide';
  const photo = agent.profiles?.photo_url || agent.photo_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      {/* TOP HEADER */}
      <div className="bg-white border-b border-gray-100 py-6 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto flex items-center justify-between">
          <Link
            to={`/agents/${agentId}`}
            className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900"
          >
            <ArrowLeft className="w-4 h-4" /> Back to Agent Profile
          </Link>
          <span className="text-xs font-extrabold uppercase tracking-wider text-[#E8741F] bg-orange-50 px-3 py-1 rounded-full">
            Secure Booking & Group Checkout
          </span>
        </div>
      </div>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-xl border border-gray-100 space-y-8">
          
          {/* AGENT SUMMARY BAR */}
          <div className="flex items-center gap-4 p-4 bg-orange-50/60 rounded-2xl border border-orange-100">
            <img src={photo} alt={name} className="w-14 h-14 rounded-2xl object-cover border-2 border-orange-200 shrink-0" />
            <div className="space-y-0.5">
              <div className="flex items-center gap-1.5">
                <h2 className="font-extrabold text-gray-900 text-base">{name}</h2>
                <ShieldCheck className="w-4 h-4 text-emerald-500" />
              </div>
              <p className="text-xs text-gray-600 font-medium">
                Daily Rate: <span className="font-extrabold text-[#E8741F]">₹{agent.price_per_day || 1500}/day</span>
              </p>
              {hasPriorCompletedBooking && (
                <span className="inline-flex items-center gap-1 text-[10px] font-extrabold text-[#8B61F1] bg-purple-50 px-2 py-0.5 rounded-md mt-1">
                  ⭐ Repeat Guide • 5% Loyalty Reward Applies!
                </span>
              )}
            </div>
          </div>

          {error && (
            <div className="p-4 bg-rose-50 border border-rose-200 text-rose-700 text-xs font-bold rounded-xl flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-500 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleCreateBooking} className="space-y-6">
            {/* DATES & DESTINATION */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1.5">Destination Circuit</label>
                <div className="relative">
                  <MapPin className="w-4 h-4 absolute left-3 top-3.5 text-gray-400" />
                  <input
                    type="text"
                    required
                    value={destination}
                    onChange={(e) => setDestination(e.target.value)}
                    placeholder="e.g. Munnar, Leh, Goa..."
                    className="w-full pl-9 pr-3 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-xs font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
                  />
                </div>
              </div>

              {/* FEATURE 3: NUMBER OF TRAVELLERS STEPPER */}
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1.5 flex items-center justify-between">
                  <span>Number of Travellers (Group Size)</span>
                  <span className="text-[10px] text-[#E8741F] font-extrabold">{groupSize} Person{groupSize > 1 ? 's' : ''}</span>
                </label>
                <div className="flex items-center justify-between px-3 py-2 bg-gray-50 border border-gray-200 rounded-xl">
                  <span className="text-xs font-bold text-gray-700 flex items-center gap-1.5">
                    <Users className="w-4 h-4 text-gray-400" />
                    {groupSize === 1 ? 'Solo Traveller' : `Group of ${groupSize}`}
                  </span>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => handleGroupSizeChange(groupSize - 1)}
                      disabled={groupSize <= 1}
                      className="w-7 h-7 rounded-lg bg-white border border-gray-200 flex items-center justify-center text-gray-600 hover:bg-gray-100 disabled:opacity-30"
                    >
                      <Minus className="w-3.5 h-3.5" />
                    </button>
                    <span className="w-6 text-center text-sm font-extrabold text-gray-900">{groupSize}</span>
                    <button
                      type="button"
                      onClick={() => handleGroupSizeChange(groupSize + 1)}
                      disabled={groupSize >= 25}
                      className="w-7 h-7 rounded-lg bg-white border border-gray-200 flex items-center justify-center text-gray-600 hover:bg-gray-100 disabled:opacity-30"
                    >
                      <Plus className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1.5">Trip Start Date</label>
                <input
                  type="date"
                  required
                  min={new Date().toISOString().split('T')[0]}
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="w-full px-3 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-xs font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1.5">Trip End Date</label>
                <input
                  type="date"
                  required
                  min={startDate || new Date().toISOString().split('T')[0]}
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="w-full px-3 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-xs font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
                />
              </div>
            </div>

            {/* FEATURE 3: OPTIONAL GROUP MEMBER DETAILS */}
            {groupSize > 1 && (
              <div className="p-4 bg-gray-50 rounded-2xl border border-gray-200 space-y-3">
                <div
                  className="flex items-center justify-between cursor-pointer"
                  onClick={() => setShowMemberForm(!showMemberForm)}
                >
                  <div className="flex items-center gap-2">
                    <Users className="w-4 h-4 text-[#8B61F1]" />
                    <span className="text-xs font-extrabold text-gray-800">
                      Additional Group Members ({groupSize - 1} co-traveller{groupSize > 2 ? 's' : ''})
                    </span>
                    <span className="text-[10px] text-gray-400 font-bold uppercase">(Optional)</span>
                  </div>
                  {showMemberForm ? <ChevronUp className="w-4 h-4 text-gray-400" /> : <ChevronDown className="w-4 h-4 text-gray-400" />}
                </div>

                {showMemberForm && (
                  <div className="space-y-3 pt-2">
                    <p className="text-[11px] text-gray-500 font-medium">
                      Primary booker's details are already registered. Optionally enter names & phone numbers for additional guests so your guide can prepare:
                    </p>
                    {groupMembers.map((member, idx) => (
                      <div key={idx} className="grid grid-cols-1 sm:grid-cols-2 gap-2 p-2.5 bg-white rounded-xl border border-gray-200">
                        <input
                          type="text"
                          placeholder={`Guest #${idx + 2} Full Name`}
                          value={member.name}
                          onChange={(e) => handleMemberChange(idx, 'name', e.target.value)}
                          className="px-3 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-xs font-medium text-gray-800 focus:outline-none focus:bg-white"
                        />
                        <input
                          type="tel"
                          placeholder={`Guest #${idx + 2} Phone (Optional)`}
                          value={member.phone}
                          onChange={(e) => handleMemberChange(idx, 'phone', e.target.value)}
                          className="px-3 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-xs font-medium text-gray-800 focus:outline-none focus:bg-white"
                        />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* MEETING POINT & TRIP PLAN */}
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1.5">Preferred Meeting Point</label>
                <input
                  type="text"
                  value={meetingPoint}
                  onChange={(e) => setMeetingPoint(e.target.value)}
                  placeholder="e.g. Cochin Airport, Hotel Lobby, Central Railway Station..."
                  className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-xs font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1.5">Special Requests or Custom Itinerary Notes</label>
                <textarea
                  rows={2}
                  value={tripPlan}
                  onChange={(e) => setTripPlan(e.target.value)}
                  placeholder="Any dietary restrictions, physical fitness levels, or specific sites you want to visit..."
                  className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl text-xs font-semibold text-gray-900 focus:outline-none focus:border-[#E8741F] focus:bg-white"
                />
              </div>
            </div>

            {/* AGENT ADDONS SELECTION (IF ANY) */}
            {addons.length > 0 && (
              <div className="p-4 bg-purple-50/50 rounded-2xl border border-purple-100 space-y-3">
                <h3 className="text-xs font-extrabold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
                  <Sparkles className="w-3.5 h-3.5 text-[#8B61F1]" /> Optional Trip Add-ons
                </h3>
                <div className="space-y-2">
                  {addons.map((addon) => {
                    const isSelected = selectedAddonIds.includes(addon.id);
                    const calcPrice = addon.per_person ? addon.price * groupSize : addon.price;

                    return (
                      <label
                        key={addon.id}
                        className={`flex items-center justify-between p-3 rounded-xl border cursor-pointer transition-all ${
                          isSelected
                            ? 'bg-white border-[#8B61F1] shadow-xs'
                            : 'bg-white/60 border-gray-200 hover:bg-white'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <input
                            type="checkbox"
                            checked={isSelected}
                            onChange={() => toggleAddon(addon.id)}
                            className="rounded text-[#8B61F1] focus:ring-0 cursor-pointer"
                          />
                          <div>
                            <span className="text-xs font-bold text-gray-800">{addon.title}</span>
                            {addon.per_person && (
                              <span className="ml-2 text-[10px] text-gray-400 font-semibold">
                                (₹{addon.price}/person × {groupSize})
                              </span>
                            )}
                          </div>
                        </div>
                        <span className="text-xs font-extrabold text-[#8B61F1]">₹{calcPrice}</span>
                      </label>
                    );
                  })}
                </div>
              </div>
            )}

            {/* FEATURE 4: LOYALTY REWARDS APPLICATION */}
            {loyaltyRewards.length > 0 && (
              <div className="p-4 bg-emerald-50/60 rounded-2xl border border-emerald-200/80 space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="text-xs font-extrabold text-emerald-900 uppercase tracking-wider flex items-center gap-1.5">
                    <Gift className="w-4 h-4 text-emerald-600" /> Apply Available Loyalty Reward
                  </h3>
                  <span className="text-[10px] font-extrabold text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-md">
                    {loyaltyRewards.length} Available
                  </span>
                </div>

                <div className="space-y-2">
                  {loyaltyRewards.map((rew) => {
                    const isApplied = selectedRewardId === rew.id;
                    return (
                      <label
                        key={rew.id}
                        className={`flex items-center justify-between p-3 rounded-xl border cursor-pointer transition-all ${
                          isApplied
                            ? 'bg-white border-emerald-500 shadow-xs ring-1 ring-emerald-500'
                            : 'bg-white/70 border-emerald-200 hover:bg-white'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <input
                            type="radio"
                            name="loyalty_reward"
                            checked={isApplied}
                            onChange={() => setSelectedRewardId(isApplied ? null : rew.id)}
                            onClick={() => {
                              if (isApplied) setSelectedRewardId(null);
                            }}
                            className="text-emerald-600 focus:ring-0 cursor-pointer"
                          />
                          <div>
                            <span className="text-xs font-extrabold text-gray-900">{rew.description}</span>
                            <span className="block text-[10px] text-gray-500">
                              Save {rew.discount_percent}% off your booking total
                            </span>
                          </div>
                        </div>
                        <span className="text-xs font-extrabold text-emerald-600">
                          {rew.discount_percent}% OFF
                        </span>
                      </label>
                    );
                  })}
                </div>
              </div>
            )}

            {/* PROMO CODE / COUPON INPUT */}
            <div className="p-4 bg-orange-50/60 rounded-2xl border border-orange-200/80 space-y-3">
              <h3 className="text-xs font-extrabold text-gray-900 uppercase tracking-wider flex items-center gap-1.5">
                <Tag className="w-4 h-4 text-[#E8741F]" /> Apply Promo Code or Referral Code
              </h3>

              <div className="flex gap-2">
                <input
                  type="text"
                  value={couponCode}
                  onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                  placeholder="e.g. GUIDE25 or REF-ALEX-8821"
                  className="flex-1 px-3.5 py-2 bg-white border border-gray-200 rounded-xl text-xs font-bold text-gray-900 focus:outline-none focus:border-[#E8741F]"
                />
                <button
                  type="button"
                  onClick={handleApplyCoupon}
                  className="px-4 py-2 bg-[#E8741F] text-white font-extrabold text-xs rounded-xl hover:bg-[#D66311] transition-all"
                >
                  Apply Code
                </button>
              </div>

              {couponMsg.text && (
                <p className={`text-xs font-bold ${couponMsg.isError ? 'text-rose-600' : 'text-emerald-600'}`}>
                  {couponMsg.text}
                </p>
              )}
            </div>

            {/* ESTIMATED DAILY CASH EXPENSES - INFORMATIONAL ONLY */}
            <div className="p-4 bg-amber-50/90 rounded-2xl border border-amber-200 space-y-3">
              <div className="flex items-start justify-between gap-3">
                <div className="space-y-1">
                  <div className="flex items-center gap-1.5">
                    <span className="text-base">💵</span>
                    <h3 className="text-xs font-extrabold text-amber-950 uppercase tracking-wider">
                      Estimated Cash to Carry (Informational Only)
                    </h3>
                  </div>
                  <p className="text-xs text-amber-900 font-medium leading-relaxed">
                    Estimated cash to carry per day: <strong>₹{customDailyExpenses}</strong> (accommodation, food, local transport — pay directly, not through the app).
                  </p>
                </div>
                <div className="w-28 text-right shrink-0">
                  <label className="block text-[10px] font-bold text-amber-800 uppercase mb-0.5">Per Day (₹)</label>
                  <input
                    type="number"
                    min="0"
                    step="100"
                    value={customDailyExpenses}
                    onChange={(e) => setCustomDailyExpenses(Number(e.target.value) || 0)}
                    className="w-full px-2 py-1 bg-white border border-amber-300 rounded-lg text-xs font-bold text-gray-900 text-right focus:outline-none focus:border-[#E8741F]"
                  />
                </div>
              </div>
              <div className="pt-2.5 border-t border-amber-200/70 flex items-center justify-between text-xs">
                <span className="text-amber-900 font-semibold">Total estimated cash to carry yourself ({days || 1} day{(days || 1) > 1 ? 's' : ''}):</span>
                <span className="font-extrabold text-amber-950 text-sm">₹{((days || 1) * customDailyExpenses).toLocaleString()}</span>
              </div>
              <p className="text-[11px] text-amber-800/80 italic">
                * This amount is carried in cash by you and paid directly to local vendors. It is <strong>NEVER</strong> charged through TravelVibe.
              </p>
            </div>

            {/* PRICE BREAKDOWN CARD */}
            <div className="p-5 bg-gray-50 rounded-2xl border border-gray-200 space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="text-xs font-extrabold text-gray-900 uppercase tracking-wider">App Payment Summary</h3>
                <span className="text-[10px] font-extrabold text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-full">
                  Guide Fee Only
                </span>
              </div>
              
              <div className="space-y-1.5 text-xs text-gray-600">
                <div className="flex justify-between">
                  <span>Base Guide Service Fee ({days} day{days > 1 ? 's' : ''} × ₹{baseRate}/day)</span>
                  <span className="font-bold text-gray-800">₹{baseGuideTotal}</span>
                </div>

                <div className="flex justify-between">
                  <span>Group Size:</span>
                  <span className="font-bold text-gray-800">{groupSize} Person{groupSize > 1 ? 's' : ''} (Flat Guide Fee)</span>
                </div>

                {addonsTotal > 0 && (
                  <div className="flex justify-between text-[#8B61F1]">
                    <span>Add-ons Total:</span>
                    <span className="font-bold">₹{addonsTotal}</span>
                  </div>
                )}

                {rewardDiscountAmount > 0 && (
                  <div className="flex justify-between text-emerald-600 font-bold">
                    <span>Loyalty Reward ({discountPercent}% Discount):</span>
                    <span>-₹{rewardDiscountAmount}</span>
                  </div>
                )}

                {couponDiscountAmount > 0 && (
                  <div className="flex justify-between text-emerald-600 font-bold">
                    <span>Promo / Referral Discount ({appliedCoupon?.code}):</span>
                    <span>-₹{couponDiscountAmount}</span>
                  </div>
                )}
              </div>

              {/* DUAL SUMMARY: APP CHARGE VS DIRECT CASH */}
              <div className="pt-3 border-t border-gray-200 grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="p-3 bg-white rounded-xl border-2 border-[#E8741F]/30">
                  <span className="text-[10px] font-extrabold text-[#E8741F] uppercase tracking-wider block">
                    Charged via TravelVibe
                  </span>
                  <p className="text-xl font-black text-[#E8741F]">₹{finalTotal.toLocaleString()}</p>
                  <p className="text-[10px] text-gray-500 mt-0.5 font-medium">Guide service fee only (50% on start / 50% on completion)</p>
                </div>

                <div className="p-3 bg-amber-50/60 rounded-xl border border-amber-200">
                  <span className="text-[10px] font-extrabold text-amber-900 uppercase tracking-wider block">
                    Carry Yourself (Cash)
                  </span>
                  <p className="text-xl font-black text-amber-950">₹{((days || 1) * customDailyExpenses).toLocaleString()}</p>
                  <p className="text-[10px] text-amber-800 mt-0.5 font-medium">Pay hotels, food & travel directly in person</p>
                </div>
              </div>
            </div>

            {/* SUBMIT BUTTON */}
            <button
              type="submit"
              disabled={submitting || days <= 0}
              className="w-full py-4 bg-[#E8741F] text-white font-extrabold text-sm rounded-2xl shadow-lg hover:bg-[#D66311] transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <CreditCard className="w-4 h-4" />
              {submitting ? 'Confirming Booking Request...' : 'Send Booking Request'}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
