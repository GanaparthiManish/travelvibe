import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase, getFreshUserId } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { ShieldAlert, Clock, CheckCircle2, RefreshCw } from 'lucide-react';

export default function AgentPending() {
  const { user, refreshProfile } = useAuth();
  const navigate = useNavigate();
  const [checking, setChecking] = useState(false);

  const checkStatus = async () => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    setChecking(true);
    try {
      const { data } = await supabase
        .from('agent_details')
        .select('verified')
        .eq('id', currentUserId)
        .maybeSingle();

      if (data?.verified === true) {
        await refreshProfile();
        navigate('/agent/dashboard');
      }
    } catch (err) {
      console.error('Error checking verification status:', err);
    } finally {
      setChecking(false);
    }
  };

  useEffect(() => {
    checkStatus();

    if (!user?.id) return;

    // Real-time listener for agent verification approval by admin
    const channel = supabase
      .channel(`agent_verification_${user.id}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'agent_details',
          filter: `id=eq.${user.id}`,
        },
        async (payload) => {
          if (payload.new && payload.new.verified === true) {
            await refreshProfile();
            navigate('/agent/dashboard');
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [user]);

  return (
    <div className="min-h-[85vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8 bg-[#F7F6FB]">
      <div className="max-w-md w-full bg-white rounded-3xl p-8 shadow-xl border border-gray-100 text-center space-y-6">
        
        <div className="w-16 h-16 bg-amber-100 rounded-3xl flex items-center justify-center mx-auto text-amber-600 animate-pulse">
          <Clock className="w-8 h-8" />
        </div>

        <div className="space-y-2">
          <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Verification Pending</h2>
          <p className="text-sm font-semibold text-gray-500 leading-relaxed">
            Your agent profile and verification documents are currently under review by TravelVibe Administration.
          </p>
        </div>

        <div className="p-4 bg-amber-50 rounded-2xl border border-amber-200 text-left text-xs font-semibold text-amber-800 space-y-1">
          <p className="font-bold flex items-center gap-1.5">
            <ShieldAlert className="w-4 h-4 text-amber-600" /> Real-time Approval Sync
          </p>
          <p>
            Once our team approves your document, this page will automatically redirect you to your Agent Console.
          </p>
        </div>

        <button
          onClick={checkStatus}
          disabled={checking}
          className="w-full py-3 bg-gray-100 hover:bg-gray-200 text-gray-800 font-bold text-xs rounded-xl flex items-center justify-center gap-2 transition-all"
        >
          <RefreshCw className={`w-4 h-4 ${checking ? 'animate-spin' : ''}`} />
          {checking ? 'Checking Status...' : 'Check Status Manually'}
        </button>

      </div>
    </div>
  );
}
