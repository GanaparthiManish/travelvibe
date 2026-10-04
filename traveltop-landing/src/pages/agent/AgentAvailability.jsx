import React, { useState, useEffect } from 'react';
import { supabase, getFreshUserId } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { Calendar as CalendarIcon, CheckCircle2, Lock, Plus, Trash2, ArrowLeft } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function AgentAvailability() {
  const { user } = useAuth();
  const [selectedDate, setSelectedDate] = useState('');
  const [isBlocked, setIsBlocked] = useState(true);
  const [availabilityList, setAvailabilityList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [msg, setMsg] = useState(null);

  const fetchAvailability = async () => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      setLoading(true);
      const { data } = await supabase
        .from('availability')
        .select('*')
        .eq('agent_id', currentUserId)
        .order('date', { ascending: true });

      setAvailabilityList(data || []);
    } catch (err) {
      console.error('Error fetching availability:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAvailability();
  }, [user]);

  const handleAddDate = async (e) => {
    e.preventDefault();
    if (!selectedDate) return;

    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      const { error: insertErr } = await supabase.from('availability').upsert(
        {
          agent_id: currentUserId,
          date: selectedDate,
          is_available: !isBlocked,
          is_blocked: isBlocked,
        },
        { onConflict: 'agent_id, date' }
      );

      if (insertErr) throw insertErr;

      setMsg(`Date ${selectedDate} marked as ${isBlocked ? 'Blocked' : 'Available'}`);
      setSelectedDate('');
      fetchAvailability();
    } catch (err) {
      console.error('Error updating availability:', err);
      alert('Failed to update availability: ' + err.message);
    }
  };

  const handleRemoveDate = async (id) => {
    try {
      await supabase.from('availability').delete().eq('id', id);
      setAvailabilityList((prev) => prev.filter((a) => a.id !== id));
    } catch (err) {
      console.error('Error removing date:', err);
    }
  };

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto space-y-2">
          <Link to="/agent/dashboard" className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900 mb-2">
            <ArrowLeft className="w-4 h-4" /> Back to Console
          </Link>
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">Calendar Availability Management</h1>
          <p className="text-sm font-semibold text-gray-500">Block off personal days or set special guide availability</p>
        </div>
      </section>

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        
        {/* ADD DATE FORM */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-4">
          <h2 className="text-lg font-extrabold text-gray-900">Mark Date Availability</h2>

          {msg && (
            <div className="p-3 bg-emerald-50 text-emerald-800 text-xs font-bold rounded-xl flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" /> {msg}
            </div>
          )}

          <form onSubmit={handleAddDate} className="grid grid-cols-1 sm:grid-cols-3 gap-4 items-end">
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Select Date</label>
              <input
                type="date"
                required
                value={selectedDate}
                onChange={(e) => setSelectedDate(e.target.value)}
                min={new Date().toISOString().split('T')[0]}
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Status</label>
              <select
                value={isBlocked ? 'blocked' : 'available'}
                onChange={(e) => setIsBlocked(e.target.value === 'blocked')}
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-bold text-sm focus:outline-none focus:border-[#8B61F1]"
              >
                <option value="blocked">🔒 Blocked (Not Available)</option>
                <option value="available">✅ Available for Booking</option>
              </select>
            </div>

            <button
              type="submit"
              className="py-3.5 bg-[#8B61F1] text-white font-bold text-sm rounded-xl shadow-md hover:bg-purple-700 flex items-center justify-center gap-2"
            >
              <Plus className="w-4 h-4" /> Save Calendar Date
            </button>
          </form>
        </div>

        {/* CALENDAR LIST */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-4">
          <h2 className="text-lg font-extrabold text-gray-900">Custom Dates Set ({availabilityList.length})</h2>

          {loading ? (
            <div className="h-32 bg-gray-200 rounded-2xl animate-pulse"></div>
          ) : availabilityList.length === 0 ? (
            <p className="text-sm font-semibold text-gray-500 text-center py-6">
              No custom date overrides set. You are available by default on all unbooked dates.
            </p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3">
              {availabilityList.map((item) => (
                <div
                  key={item.id}
                  className={`p-4 rounded-2xl border flex items-center justify-between ${
                    item.is_blocked || !item.is_available
                      ? 'bg-rose-50 border-rose-200 text-rose-800'
                      : 'bg-emerald-50 border-emerald-200 text-emerald-800'
                  }`}
                >
                  <div className="space-y-0.5">
                    <p className="font-extrabold text-sm">{item.date}</p>
                    <span className="text-[10px] font-extrabold uppercase">
                      {item.is_blocked || !item.is_available ? '🔒 Blocked' : '✅ Available'}
                    </span>
                  </div>
                  <button
                    onClick={() => handleRemoveDate(item.id)}
                    className="p-1.5 hover:bg-white rounded-lg transition-colors text-gray-400 hover:text-rose-600"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
