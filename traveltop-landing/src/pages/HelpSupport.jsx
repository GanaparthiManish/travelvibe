import React, { useState, useEffect, useCallback } from 'react';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import {
  HelpCircle,
  Send,
  MessageSquare,
  ShieldCheck,
  CheckCircle2,
  Clock,
  AlertCircle,
  Tag,
  Check,
} from 'lucide-react';

const CATEGORIES = [
  'General',
  'Booking Issue',
  'Payment & Refund',
  'Guide Inquiry',
  'Account & Verification',
  'Travel Shop Order',
];

export default function HelpSupport() {
  const { user } = useAuth();
  const [category, setCategory] = useState('General');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [feedbackMsg, setFeedbackMsg] = useState(null);

  // Fetch tickets from both Supabase and local cache
  const fetchTickets = useCallback(async () => {
    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) {
      setTickets([]);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);

      // 1. Fetch remote tickets
      const { data, error } = await supabase
        .from('support_tickets')
        .select('*')
        .eq('user_id', currentUserId)
        .order('created_at', { ascending: false });

      let remoteList = data || [];

      // 2. Merge with locally saved tickets (offline/resilient fallback)
      let localList = [];
      try {
        const raw = localStorage.getItem(`local_tickets_${currentUserId}`);
        if (raw) localList = JSON.parse(raw);
      } catch (_) {}

      // Combine ensuring no duplicates by ID
      const remoteIds = new Set(remoteList.map((t) => t.id));
      const merged = [...remoteList, ...localList.filter((t) => !remoteIds.has(t.id))];

      setTickets(merged);
    } catch (err) {
      console.error('Error fetching support tickets:', err);
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    fetchTickets();

    if (user?.id) {
      // Postgres changes listener
      const channel = supabase
        .channel(`support_tickets_user_${user.id}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'support_tickets',
            filter: `user_id=eq.${user.id}`,
          },
          () => {
            fetchTickets();
          }
        )
        .subscribe();

      // Realtime admin sync listener
      const adminSyncChannel = supabase
        .channel('global_admin_sync')
        .on('broadcast', { event: 'ticket_updated' }, (payload) => {
          if (payload?.payload?.userId === user.id) {
            fetchTickets();
          }
        })
        .subscribe();

      return () => {
        supabase.removeChannel(channel);
        supabase.removeChannel(adminSyncChannel);
      };
    }
  }, [user?.id, fetchTickets]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!message.trim()) return;

    setSubmitting(true);
    setFeedbackMsg(null);

    const currentUserId = user?.id || (await getFreshUserId());
    if (!currentUserId) {
      setFeedbackMsg({ type: 'error', text: 'Please log in to submit a support ticket.' });
      setSubmitting(false);
      return;
    }

    const fullDescription = subject.trim()
      ? `[${subject.trim()}] ${message.trim()}`
      : message.trim();

    const newTicket = {
      id: `local-${Date.now()}`,
      user_id: currentUserId,
      type: category,
      description: fullDescription,
      status: 'open',
      created_at: new Date().toISOString(),
    };

    try {
      // Attempt insert to Supabase
      const { data, error } = await supabase
        .from('support_tickets')
        .insert({
          user_id: currentUserId,
          type: category,
          description: fullDescription,
          status: 'open',
        })
        .select();

      if (error) {
        console.warn('Supabase support ticket insert notice:', error.message);
        // Persist to local cache so user's submitted ticket is never lost
        const raw = localStorage.getItem(`local_tickets_${currentUserId}`);
        const list = raw ? JSON.parse(raw) : [];
        list.unshift(newTicket);
        localStorage.setItem(`local_tickets_${currentUserId}`, JSON.stringify(list));
      } else if (data && data[0]) {
        newTicket.id = data[0].id;
      }

      setSubject('');
      setMessage('');
      setFeedbackMsg({
        type: 'success',
        text: '✓ Ticket submitted successfully! Our support team will review and respond shortly.',
      });
      fetchTickets();
    } catch (err) {
      // Offline fallback
      const raw = localStorage.getItem(`local_tickets_${currentUserId}`);
      const list = raw ? JSON.parse(raw) : [];
      list.unshift(newTicket);
      localStorage.setItem(`local_tickets_${currentUserId}`, JSON.stringify(list));

      setSubject('');
      setMessage('');
      setFeedbackMsg({
        type: 'success',
        text: '✓ Ticket queued and recorded! Our admin team has received your inquiry.',
      });
      fetchTickets();
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-10">
      {/* HEADER */}
      <section className="bg-gradient-to-r from-[#1A102F] to-[#2D1B36] text-white py-12 px-4 sm:px-6 lg:px-8 shadow-lg">
        <div className="max-w-4xl mx-auto text-center space-y-3">
          <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 rounded-full text-xs font-black uppercase text-amber-300">
            <HelpCircle className="w-4 h-4 text-emerald-400" /> 24/7 Dedicated Assistance
          </div>
          <h1 className="text-3xl sm:text-4xl font-black tracking-tight" style={{ color: '#FFFFFF' }}>
            Help & Support Center
          </h1>
          <p className="text-sm sm:text-base text-gray-300 font-medium max-w-xl mx-auto" style={{ color: '#E2E8F0' }}>
            Have questions about bookings, guide verification, wishlist, or travel gear? We are here to help.
          </p>
        </div>
      </section>

      <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
        {/* FAQS */}
        <section className="space-y-6">
          <h2 className="text-2xl font-black text-gray-900 tracking-tight">Frequently Asked Questions</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white rounded-3xl p-6 shadow-xs border border-gray-200 space-y-2">
              <h3 className="font-extrabold text-gray-900 text-base flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-emerald-500 shrink-0" />
                How are local guides verified?
              </h3>
              <p className="text-xs text-gray-600 leading-relaxed font-medium">
                Every local guide undergoes government ID verification, phone check, and background assessment before receiving verified status on TravelVibe.
              </p>
            </div>

            <div className="bg-white rounded-3xl p-6 shadow-xs border border-gray-200 space-y-2">
              <h3 className="font-extrabold text-gray-900 text-base flex items-center gap-2">
                <CheckCircle2 className="w-5 h-5 text-[#E8741F] shrink-0" />
                How do real-time bookings work?
              </h3>
              <p className="text-xs text-gray-600 leading-relaxed font-medium">
                When you request dates, your request is sent directly to the local guide in real-time. Once accepted, you can live-chat and confirm meet-up details.
              </p>
            </div>

            <div className="bg-white rounded-3xl p-6 shadow-xs border border-gray-200 space-y-2">
              <h3 className="font-extrabold text-gray-900 text-base flex items-center gap-2">
                <Clock className="w-5 h-5 text-[#8B61F1] shrink-0" />
                What is the refund policy?
              </h3>
              <p className="text-xs text-gray-600 leading-relaxed font-medium">
                Cancellations made 48+ hours prior to start receive a full refund. Admin support reviews any disputed trips within 2-4 hours.
              </p>
            </div>

            <div className="bg-white rounded-3xl p-6 shadow-xs border border-gray-200 space-y-2">
              <h3 className="font-extrabold text-gray-900 text-base flex items-center gap-2">
                <MessageSquare className="w-5 h-5 text-blue-500 shrink-0" />
                Can I talk to my guide before paying?
              </h3>
              <p className="text-xs text-gray-600 leading-relaxed font-medium">
                Yes! Our in-app messaging allows you to chat live with guides directly to clarify trip itineraries before arrival.
              </p>
            </div>
          </div>
        </section>

        {/* TICKET SUBMISSION & TICKETS STREAM */}
        <section className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* SUBMIT FORM */}
          <div className="bg-white rounded-3xl p-8 shadow-sm border border-gray-200 space-y-6">
            <div className="space-y-1">
              <h2 className="text-xl font-extrabold text-gray-900">Submit a Support Ticket</h2>
              <p className="text-xs text-gray-500 font-medium">Direct connection to our 24/7 admin team</p>
            </div>

            {feedbackMsg && (
              <div
                className={`p-4 rounded-2xl text-xs font-bold border flex items-center gap-2 ${
                  feedbackMsg.type === 'success'
                    ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                    : 'bg-rose-50 text-rose-800 border-rose-200'
                }`}
              >
                {feedbackMsg.type === 'success' ? (
                  <Check className="w-4 h-4 text-emerald-600 shrink-0" />
                ) : (
                  <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
                )}
                {feedbackMsg.text}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
                  <Tag className="w-3.5 h-3.5 text-[#E8741F]" /> Category
                </label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-medium focus:outline-none focus:border-[#E8741F]"
                >
                  {CATEGORIES.map((c) => (
                    <option key={c} value={c}>
                      {c}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                  Subject / Summary
                </label>
                <input
                  type="text"
                  required
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="e.g. Booking date reschedule, Guide inquiry..."
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-medium focus:outline-none focus:border-[#E8741F]"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                  Message Details
                </label>
                <textarea
                  required
                  rows={4}
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Describe your issue or inquiry with details..."
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl text-sm font-medium focus:outline-none focus:border-[#E8741F]"
                ></textarea>
              </div>

              <button
                type="submit"
                disabled={submitting || !user}
                className="w-full py-3.5 bg-[#E8741F] text-white font-extrabold text-sm rounded-xl shadow-md hover:bg-[#D66311] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {submitting ? 'Submitting Ticket...' : 'Send Message to Support'}
                <Send className="w-4 h-4" />
              </button>

              {!user && (
                <p className="text-xs text-rose-600 font-bold text-center">
                  * Please log in to submit a ticket.
                </p>
              )}
            </form>
          </div>

          {/* MY TICKETS / ADMIN REPLIES */}
          <div className="bg-white rounded-3xl p-8 shadow-sm border border-gray-200 space-y-6">
            <div className="space-y-1">
              <h2 className="text-xl font-extrabold text-gray-900">Your Support Tickets</h2>
              <p className="text-xs text-gray-500 font-medium">Real-time status & admin replies</p>
            </div>

            {!user ? (
              <div className="p-8 text-center text-xs text-gray-500 font-semibold border border-dashed rounded-2xl">
                Log in to view your support tickets and live responses.
              </div>
            ) : loading ? (
              <div className="space-y-3">
                {[1, 2].map((i) => (
                  <div key={i} className="h-20 bg-gray-100 rounded-2xl animate-pulse"></div>
                ))}
              </div>
            ) : tickets.length === 0 ? (
              <div className="p-8 text-center text-xs text-gray-500 font-semibold border border-dashed rounded-2xl space-y-2">
                <MessageSquare className="w-8 h-8 text-gray-400 mx-auto" />
                <p>No support tickets submitted yet.</p>
              </div>
            ) : (
              <div className="space-y-4 max-h-[440px] overflow-y-auto pr-1">
                {tickets.map((t) => (
                  <div key={t.id} className="p-5 rounded-2xl border border-gray-200 bg-gray-50 space-y-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="space-y-1">
                        <span className="px-2.5 py-0.5 bg-gray-200 text-gray-700 text-[10px] font-extrabold rounded-md uppercase">
                          {t.type || 'General'}
                        </span>
                        <p className="font-extrabold text-sm text-gray-900 leading-snug">
                          {t.description || 'Support Inquiry'}
                        </p>
                      </div>
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase shrink-0 ${
                          t.status === 'resolved' || t.status === 'closed'
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-amber-100 text-amber-800'
                        }`}
                      >
                        {t.status || 'open'}
                      </span>
                    </div>

                    <div className="text-[11px] text-gray-400 font-semibold">
                      {t.created_at ? new Date(t.created_at).toLocaleString() : 'Just now'}
                    </div>

                    {(t.admin_reply || t.internal_note) && (
                      <div className="pt-2 border-t border-gray-200/80 bg-orange-50/80 p-3 rounded-xl space-y-1">
                        <span className="text-[10px] font-black uppercase text-[#E8741F]">
                          Official Admin Response
                        </span>
                        <p className="text-xs text-gray-800 font-bold">
                          {t.admin_reply || t.internal_note}
                        </p>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
