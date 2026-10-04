import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { Mail, Lock, ShieldCheck, AlertCircle, ArrowRight } from 'lucide-react';

export default function AgentLogin() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const navigate = useNavigate();
  const { user, profile, loading: authLoading, refreshProfile } = useAuth();

  // Redirect if already logged in as agent
  useEffect(() => {
    if (!authLoading && user) {
      if (profile?.role === 'agent') {
        supabase
          .from('agent_details')
          .select('verified, suspended')
          .eq('id', user.id)
          .maybeSingle()
          .then(({ data: ag }) => {
            if (ag?.suspended === true || profile?.suspended === true) {
              setError('⚠️ Your account has been suspended by administration. Please contact support.');
              return;
            }
            if (ag?.verified === true) {
              navigate('/agent/dashboard', { replace: true });
            } else {
              navigate('/agent/pending', { replace: true });
            }
          });
      }
    }
  }, [user, profile, authLoading, navigate]);

  const handleLogin = async (e) => {
    e.preventDefault();
    if (!email || !password) {
      setError('Please enter email and password.');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const { data, error: signInErr } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password: password.trim(),
      });

      if (signInErr) throw signInErr;

      const userId = data.user.id;
      const freshProf = await refreshProfile(userId);

      // Check agent verification & suspension status
      const { data: ag } = await supabase
        .from('agent_details')
        .select('verified, suspended')
        .eq('id', userId)
        .maybeSingle();

      if (ag?.suspended === true || freshProf?.suspended === true) {
        await supabase.auth.signOut();
        setError('⚠️ Your account has been suspended by administration. Please contact support.');
        return;
      }

      if (ag?.verified === true) {
        navigate('/agent/dashboard', { replace: true });
      } else {
        navigate('/agent/pending', { replace: true });
      }
    } catch (err) {
      const msg = err.message || '';
      if (msg.toLowerCase().includes('email not confirmed')) {
        setError('Your email is not confirmed yet. Please verify your email before logging in.');
      } else {
        setError(msg || 'Agent sign in failed.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8 bg-[#F7F6FB]">
      <div className="max-w-md w-full bg-white rounded-3xl p-8 shadow-xl border border-gray-100 space-y-6">
        
        {/* HEADER */}
        <div className="text-center space-y-2">
          <div className="w-12 h-12 bg-purple-100 rounded-2xl flex items-center justify-center mx-auto text-[#8B61F1]">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Agent Console Login</h2>
          <p className="text-sm font-semibold text-gray-500">Sign in to manage your guide bookings & availability</p>
        </div>

        {/* ERROR ALERT */}
        {error && (
          <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 flex items-start gap-3 text-rose-700 text-sm font-semibold">
            <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
            <div>{error}</div>
          </div>
        )}

        {/* FORM */}
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Agent Email Address</label>
            <div className="relative">
              <Mail className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="agent@example.com"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1] focus:bg-white transition-all"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Password</label>
            <div className="relative">
              <Lock className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1] focus:bg-white transition-all"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 bg-[#8B61F1] text-white font-bold text-sm rounded-xl shadow-md hover:bg-purple-700 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
          >
            {loading ? 'Signing in...' : 'Sign In to Agent Portal'}
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>

        <div className="pt-2 text-center text-sm font-semibold text-gray-600">
          Want to become a local guide?{' '}
          <Link to="/agent/signup" className="text-[#8B61F1] font-bold hover:underline">
            Apply as Agent
          </Link>
        </div>

      </div>
    </div>
  );
}
