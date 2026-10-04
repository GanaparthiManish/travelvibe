import React, { useState, useEffect, useRef } from 'react';
import { useParams, Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { Send, MessageSquare, ArrowLeft, ShieldCheck, User } from 'lucide-react';

export default function Chat() {
  const { bookingId } = useParams();
  const { user } = useAuth();

  const [booking, setBooking] = useState(null);
  const [messages, setMessages] = useState([]);
  const [inputText, setInputText] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const fetchChatData = async () => {
    try {
      setLoading(true);
      // Fetch booking info
      const { data: bData } = await supabase
        .from('bookings')
        .select('*, profiles!bookings_agent_id_fkey(full_name, photo_url), traveller_profile:profiles!bookings_traveller_id_fkey(full_name, photo_url)')
        .eq('id', bookingId)
        .maybeSingle();

      setBooking(bData);

      // Fetch messages
      const { data: msgs } = await supabase
        .from('messages')
        .select('*, profiles!messages_sender_id_fkey(full_name, photo_url)')
        .eq('booking_id', bookingId)
        .order('created_at', { ascending: true });

      setMessages(msgs || []);
    } catch (err) {
      console.error('Error fetching chat:', err);
    } finally {
      setLoading(false);
      setTimeout(scrollToBottom, 100);
    }
  };

  useEffect(() => {
    fetchChatData();

    // Real-time Messages Subscription
    const channel = supabase
      .channel(`chat_room_${bookingId}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `booking_id=eq.${bookingId}`,
        },
        async (payload) => {
          // Fetch sender details for new message
          const { data: senderProf } = await supabase
            .from('profiles')
            .select('full_name, photo_url')
            .eq('id', payload.new.sender_id)
            .maybeSingle();

          const newMsg = {
            ...payload.new,
            profiles: senderProf,
          };

          setMessages((prev) => [...prev, newMsg]);
          setTimeout(scrollToBottom, 100);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [bookingId]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!inputText.trim()) return;

    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      alert('Please log in to send messages.');
      return;
    }

    const content = inputText.trim();
    setInputText('');
    setSending(true);

    try {
      const { error: msgErr } = await supabase.from('messages').insert({
        booking_id: bookingId,
        sender_id: currentUserId,
        content: content,
        original_language: 'en',
        created_at: new Date().toISOString(),
      });

      if (msgErr) throw msgErr;
    } catch (err) {
      console.error('Error sending message:', err);
      alert('Failed to send message: ' + err.message);
    } finally {
      setSending(false);
    }
  };

  if (loading) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-12 animate-pulse space-y-4">
        <div className="h-20 bg-gray-200 rounded-3xl"></div>
        <div className="h-96 bg-gray-200 rounded-3xl"></div>
      </div>
    );
  }

  const otherPersonName =
    user?.id === booking?.traveller_id
      ? booking?.profiles?.full_name || 'Local Guide'
      : booking?.traveller_profile?.full_name || 'Traveller';

  const otherPersonPhoto =
    user?.id === booking?.traveller_id
      ? booking?.profiles?.photo_url
      : booking?.traveller_profile?.photo_url;

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-[90vh] flex flex-col justify-between">
      
      {/* HEADER */}
      <div className="bg-white border-b border-gray-100 py-4 px-4 sm:px-6 lg:px-8 sticky top-18 z-40 shadow-xs">
        <div className="max-w-3xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Link to="/my-trips" className="p-2 text-gray-400 hover:text-gray-900 rounded-xl hover:bg-gray-100">
              <ArrowLeft className="w-5 h-5" />
            </Link>
            <div className="flex items-center gap-3">
              {otherPersonPhoto ? (
                <img src={otherPersonPhoto} alt={otherPersonName} className="w-10 h-10 rounded-full object-cover border-2 border-purple-200" />
              ) : (
                <div className="w-10 h-10 rounded-full bg-[#8B61F1] text-white flex items-center justify-center font-bold text-sm">
                  {otherPersonName.charAt(0)}
                </div>
              )}
              <div>
                <div className="flex items-center gap-1.5">
                  <h2 className="font-extrabold text-gray-900 text-base">{otherPersonName}</h2>
                  <ShieldCheck className="w-4 h-4 text-emerald-500" />
                </div>
                <p className="text-xs text-gray-500 font-semibold">{booking?.destination} Trip</p>
              </div>
            </div>
          </div>

          <span className="px-3 py-1 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-full">
            Realtime Connected
          </span>
        </div>
      </div>

      {/* MESSAGES BODY */}
      <div className="max-w-3xl mx-auto px-4 w-full py-6 flex-1 space-y-4">
        {messages.length === 0 ? (
          <div className="text-center py-12 text-gray-400 text-sm font-semibold space-y-2">
            <MessageSquare className="w-10 h-10 mx-auto text-gray-300" />
            <p>No messages yet. Send a message to start real-time chat!</p>
          </div>
        ) : (
          messages.map((msg) => {
            const isMe = msg.sender_id === user?.id;
            const senderName = msg.profiles?.full_name || (isMe ? 'You' : 'User');
            const timeStr = new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

            return (
              <div key={msg.id} className={`flex flex-col ${isMe ? 'items-end' : 'items-start'} space-y-1`}>
                <span className="text-[10px] font-bold text-gray-400 px-1">{senderName}</span>
                <div
                  className={`max-w-[75%] p-4 rounded-2xl text-sm font-medium shadow-xs ${
                    isMe
                      ? 'bg-gradient-to-r from-[#E8741F] to-[#E8741F] text-white rounded-br-none'
                      : 'bg-white text-gray-800 border border-gray-100 rounded-bl-none'
                  }`}
                >
                  {msg.content}
                </div>
                <span className="text-[10px] text-gray-400 font-semibold px-1">{timeStr}</span>
              </div>
            );
          })
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* CHAT INPUT BAR */}
      <div className="max-w-3xl mx-auto px-4 w-full sticky bottom-4 z-40">
        <form onSubmit={handleSendMessage} className="bg-white rounded-2xl p-2 shadow-xl border border-gray-200 flex items-center gap-2">
          <input
            type="text"
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            placeholder="Type your message..."
            className="w-full px-4 py-3 bg-transparent text-sm font-medium text-gray-900 focus:outline-none"
          />
          <button
            type="submit"
            disabled={sending || !inputText.trim()}
            className="p-3 bg-[#E8741F] text-white rounded-xl shadow-md hover:bg-[#D66311] transition-all disabled:opacity-50 shrink-0"
          >
            <Send className="w-5 h-5" />
          </button>
        </form>
      </div>

    </div>
  );
}
