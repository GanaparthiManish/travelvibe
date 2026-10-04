import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { DollarSign, ArrowLeft, Clock, CheckCircle2, AlertCircle, Building2, QrCode, ShieldCheck, AlertTriangle } from 'lucide-react';

export default function AgentEarnings() {
  const { user } = useAuth();
  const [payouts, setPayouts] = useState([]);
  const [confirmedBookings, setConfirmedBookings] = useState([]);
  const [payoutMethod, setPayoutMethod] = useState(null);
  const [loading, setLoading] = useState(true);
  const [requesting, setRequesting] = useState(false);
  const [msg, setMsg] = useState(null);

  const fetchData = async () => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      setLoading(true);
      // Fetch confirmed bookings
      const { data: bData } = await supabase
        .from('bookings')
        .select('*')
        .eq('agent_id', currentUserId)
        .in('status', ['confirmed', 'completed', 'ongoing']);

      setConfirmedBookings(bData || []);

      // Fetch payouts
      const { data: pData } = await supabase
        .from('payouts')
        .select('*')
        .eq('agent_id', currentUserId)
        .order('requested_at', { ascending: false });

      setPayouts(pData || []);

      // Fetch payout method
      const { data: pmData } = await supabase
        .from('agent_payout_methods')
        .select('*')
        .eq('agent_id', currentUserId)
        .maybeSingle();

      setPayoutMethod(pmData || null);
    } catch (err) {
      console.error('Error fetching earnings data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [user]);

  const totalEarned = confirmedBookings.reduce((sum, b) => sum + (parseFloat(b.total_price) || 0), 0);
  const totalPaidOut = payouts.filter((p) => p.status === 'paid').reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
  const pendingPayout = payouts.filter((p) => p.status === 'processing').reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
  const availableForPayout = Math.max(0, totalEarned - totalPaidOut - pendingPayout);

  const handleRequestPayout = async () => {
    if (availableForPayout <= 0) return;

    if (!payoutMethod || !payoutMethod.name_verified) {
      alert('Payout release blocked: You must link a verified payout method first. If your name is under admin review, payouts will release once approved.');
      return;
    }

    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    setRequesting(true);
    setMsg(null);

    try {
      const { error: insertErr } = await supabase.from('payouts').insert({
        agent_id: currentUserId,
        amount: availableForPayout,
        status: 'processing',
        requested_at: new Date().toISOString(),
        notes: `Manual settlement request to ${payoutMethod.method_type === 'bank' ? 'Bank' : 'UPI'}`,
      });

      if (insertErr) throw insertErr;

      setMsg(`Payout request of ₹${availableForPayout} submitted successfully!`);
      fetchData();
    } catch (err) {
      console.error('Payout request error:', err);
      alert('Failed to request payout: ' + err.message);
    } finally {
      setRequesting(false);
    }
  };

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto space-y-2">
          <Link to="/agent/dashboard" className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900 mb-2">
            <ArrowLeft className="w-4 h-4" /> Back to Console
          </Link>
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">Agent Earnings & Payouts</h1>
          <p className="text-sm font-semibold text-gray-500">Track guide revenues and request bank payout settlements</p>
        </div>
      </section>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">

        {/* PAYOUT METHOD STATUS BANNER */}
        <div className={`p-5 rounded-2xl border flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 ${
          !payoutMethod
            ? 'bg-amber-50/70 border-amber-200'
            : payoutMethod.name_verified
            ? 'bg-emerald-50/70 border-emerald-200'
            : 'bg-rose-50/70 border-rose-200'
        }`}>
          <div className="flex items-start gap-3">
            <div className={`p-2.5 rounded-xl ${
              !payoutMethod ? 'bg-amber-100 text-amber-700' : payoutMethod.name_verified ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'
            }`}>
              {!payoutMethod ? <AlertCircle className="w-5 h-5" /> : payoutMethod.name_verified ? <ShieldCheck className="w-5 h-5" /> : <AlertTriangle className="w-5 h-5" />}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-extrabold text-sm text-gray-900">
                  {!payoutMethod
                    ? 'No Payout Method Linked'
                    : payoutMethod.name_verified
                    ? `Linked Payout Method: ${payoutMethod.method_type === 'bank' ? 'Bank Account' : 'UPI ID'} (Verified)`
                    : `Payout Name Mismatch (Pending Admin Review)`}
                </h3>
                <span className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase ${
                  !payoutMethod ? 'bg-amber-100 text-amber-800' : payoutMethod.name_verified ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                }`}>
                  {!payoutMethod ? 'Action Needed' : payoutMethod.name_verified ? 'Active' : 'Locked'}
                </span>
              </div>
              <p className="text-xs text-gray-600 font-medium mt-1">
                {!payoutMethod
                  ? 'Add your bank account or UPI ID to automatically receive 30% start, daily progress, and 40% completion escrow payouts.'
                  : payoutMethod.name_verified
                  ? `${payoutMethod.method_type === 'bank' ? `A/C: ••••${payoutMethod.bank_account_number?.slice(-4)} (${payoutMethod.ifsc_code})` : `UPI: ${payoutMethod.upi_id}`} — Account holder: ${payoutMethod.account_holder_name}`
                  : `Entered "${payoutMethod.account_holder_name}". Automatic payouts are paused until Admin manually approves this account.`}
              </p>
            </div>
          </div>

          <Link
            to="/agent/payout-method"
            className={`px-4 py-2 text-xs font-bold rounded-xl border shadow-xs transition-all whitespace-nowrap ${
              !payoutMethod || !payoutMethod.name_verified
                ? 'bg-[#8B61F1] text-white border-transparent hover:bg-purple-700'
                : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
            }`}
          >
            {!payoutMethod ? 'Link Payout Method' : 'Manage Bank / UPI'}
          </Link>
        </div>
        
        {/* CARDS */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-1">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Total Revenue</span>
            <p className="text-2xl font-extrabold text-[#E8741F]">₹{totalEarned.toLocaleString()}</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-1">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Paid Out</span>
            <p className="text-2xl font-extrabold text-emerald-600">₹{totalPaidOut.toLocaleString()}</p>
          </div>

          <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-1">
            <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Available for Payout</span>
            <p className="text-2xl font-extrabold text-[#8B61F1]">₹{availableForPayout.toLocaleString()}</p>
          </div>
        </div>

        {/* REQUEST PAYOUT BUTTON */}
        <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 flex flex-col sm:flex-row items-center justify-between gap-4">
          <div>
            <h3 className="font-extrabold text-gray-900 text-base">Request Bank Payout Settlement</h3>
            <p className="text-xs text-gray-500 font-medium">Funds transferred directly into your registered bank UPI / Account</p>
          </div>

          <button
            onClick={handleRequestPayout}
            disabled={requesting || availableForPayout <= 0 || !payoutMethod?.name_verified}
            className="px-6 py-3 bg-[#8B61F1] text-white font-bold text-xs rounded-xl shadow-md hover:bg-purple-700 disabled:opacity-50 transition-all shrink-0 cursor-pointer"
          >
            {requesting ? 'Submitting...' : `Request Payout (₹${availableForPayout})`}
          </button>
        </div>

        {msg && (
          <div className="p-4 bg-emerald-50 text-emerald-800 text-xs font-bold rounded-2xl border border-emerald-200 flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-emerald-600" /> {msg}
          </div>
        )}

        {/* PAYOUT HISTORY */}
        <div className="bg-white rounded-3xl p-6 shadow-sm border border-gray-100 space-y-4">
          <h2 className="text-lg font-extrabold text-gray-900">Payout History</h2>
          
          {loading ? (
            <div className="h-32 bg-gray-200 rounded-2xl animate-pulse"></div>
          ) : payouts.length === 0 ? (
            <p className="text-sm font-semibold text-gray-500 text-center py-6">No payout requests submitted yet.</p>
          ) : (
            <div className="divide-y divide-gray-100">
              {payouts.map((p) => (
                <div key={p.id} className="py-3 flex items-center justify-between text-sm">
                  <div>
                    <span className="font-bold text-gray-900">₹{p.amount}</span>
                    <p className="text-xs text-gray-500 font-medium">{new Date(p.requested_at).toLocaleDateString()}</p>
                  </div>
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase ${
                    p.status === 'paid' ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                  }`}>
                    {p.status}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
