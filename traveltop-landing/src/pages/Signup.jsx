import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { User, Mail, Lock, Phone, UserPlus, AlertCircle, ArrowRight, Gift } from 'lucide-react';

export default function Signup() {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [referralCode, setReferralCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [successNotice, setSuccessNotice] = useState(null);

  const navigate = useNavigate();
  const { user, profile, loading: authLoading, refreshProfile } = useAuth();

  // Redirect if already logged in
  useEffect(() => {
    if (!authLoading && user) {
      if (profile?.role === 'agent') {
        navigate('/agent/dashboard', { replace: true });
      } else {
        navigate('/app', { replace: true });
      }
    }
  }, [user, profile, authLoading, navigate]);

  const handleSignup = async (e) => {
    e.preventDefault();
    if (!fullName || !email || !password) {
      setError('Please fill in all required fields.');
      return;
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }

    setLoading(true);
    setError(null);
    setSuccessNotice(null);

    try {
      // Check referral code if provided
      let referringUserId = null;
      if (referralCode.trim()) {
        try {
          const { data: refUser } = await supabase
            .from('profiles')
            .select('id, full_name')
            .ilike('referral_code', referralCode.trim())
            .maybeSingle();

          if (refUser) {
            referringUserId = refUser.id;
          }
        } catch (_) {}
      }

      // Generate initial referral code for this new user
      const cleanName = (fullName.trim().replace(/[^a-zA-Z]/g, '').slice(0, 4) || 'VIBE').toUpperCase();
      const generatedReferralCode = `${cleanName}${Math.floor(1000 + Math.random() * 9000)}`;

      // 1. Supabase Auth Sign Up
      const { data, error: signUpErr } = await supabase.auth.signUp({
        email: email.trim(),
        password: password.trim(),
        options: {
          data: {
            full_name: fullName.trim(),
            phone: phone.trim(),
            role: 'traveller',
            referral_code: generatedReferralCode,
          },
        },
      });

      if (signUpErr) throw signUpErr;

      const userId = data.user?.id;
      if (userId) {
        // 2. Insert into profiles table with role='traveller'
        const profilePayload = {
          id: userId,
          role: 'traveller',
          full_name: fullName.trim(),
          phone: phone.trim(),
          referral_code: generatedReferralCode,
          created_at: new Date().toISOString(),
        };
        if (referringUserId) {
          profilePayload.referred_by = referringUserId;
        }

        const { error: profErr } = await supabase.from('profiles').upsert(profilePayload);
        if (profErr) console.error('Profile creation notice:', profErr);

        // 3. If referred by an existing traveller, create loyalty reward for referrer & new user!
        if (referringUserId) {
          try {
            // Reward referrer
            await supabase.from('loyalty_rewards').insert({
              traveller_id: referringUserId,
              reward_type: 'referral',
              description: `10% Referral Reward for inviting ${fullName.trim()}!`,
              discount_percent: 10,
              is_used: false,
            });

            // Welcome reward for new user
            await supabase.from('loyalty_rewards').insert({
              traveller_id: userId,
              reward_type: 'referral',
              description: '10% Welcome Reward for signing up with referral code!',
              discount_percent: 10,
              is_used: false,
            });
          } catch (_) {}
        }
      }

      if (data.session) {
        await refreshProfile(userId);
        navigate('/app', { replace: true });
      } else {
        // Email confirmation is required by Supabase
        setSuccessNotice(
          `Account created! A confirmation email has been sent to ${email}. Please check your inbox and verify your email before logging in, or sign in with Google.`
        );
      }
    } catch (err) {
      const errStr = (err.message || '').toLowerCase();
      if (errStr.includes('rate limit') || errStr.includes('429') || errStr.includes('over_email_send_rate_limit')) {
        // Try sign in directly in case auth user exists
        try {
          const { data: signInData, error: signInErr } = await supabase.auth.signInWithPassword({
            email: email.trim(),
            password: password.trim(),
          });
          if (!signInErr && signInData.user) {
            await supabase.from('profiles').upsert({
              id: signInData.user.id,
              role: 'traveller',
              full_name: fullName.trim(),
              phone: phone.trim(),
              created_at: new Date().toISOString(),
            });
            await refreshProfile(signInData.user.id);
            navigate('/app', { replace: true });
            return;
          }
        } catch (_) {}

        setError(
          'Supabase email rate limit reached (free default SMTP max limit). Please turn OFF "Confirm email" in Supabase Dashboard -> Authentication -> Providers -> Email, or sign in with Google.'
        );
      } else {
        setError(err.message || 'Registration failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignIn = async () => {
    setLoading(true);
    setError(null);
    try {
      const { error: oAuthErr } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: window.location.origin + '/app',
        },
      });
      if (oAuthErr) throw oAuthErr;
    } catch (err) {
      setError('Google Sign-In error: ' + (err.message || err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8 bg-[#F7F6FB]">
      <div className="max-w-md w-full bg-white rounded-3xl p-8 shadow-xl border border-gray-100 space-y-6">
        
        {/* HEADER */}
        <div className="text-center space-y-2">
          <div className="w-12 h-12 bg-orange-100 rounded-2xl flex items-center justify-center mx-auto text-[#E8741F]">
            <UserPlus className="w-6 h-6" />
          </div>
          <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Create Account</h2>
          <p className="text-sm font-semibold text-gray-500">Start exploring with local guides today</p>
        </div>

        {/* ERROR ALERT */}
        {error && (
          <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 flex items-start gap-3 text-rose-700 text-sm font-semibold">
            <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" />
            <div>{error}</div>
          </div>
        )}

        {/* SUCCESS ALERT */}
        {successNotice && (
          <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm font-semibold space-y-2">
            <p>{successNotice}</p>
            <Link
              to="/login"
              className="inline-block mt-2 px-4 py-2 bg-emerald-600 text-white text-xs font-bold rounded-xl hover:bg-emerald-700 transition-all"
            >
              Go to Sign In
            </Link>
          </div>
        )}

        {/* FORM */}
        <form onSubmit={handleSignup} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Full Name</label>
            <div className="relative">
              <User className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="text"
                required
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder="Alex Johnson"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F] focus:bg-white transition-all"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Email Address</label>
            <div className="relative">
              <Mail className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F] focus:bg-white transition-all"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Phone Number (Optional)</label>
            <div className="relative">
              <Phone className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                placeholder="+91 98765 43210"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F] focus:bg-white transition-all"
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
                placeholder="At least 6 characters"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F] focus:bg-white transition-all"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
              Referral Code <span className="text-gray-400 font-normal">(Optional — Get 10% Off)</span>
            </label>
            <div className="relative">
              <Gift className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
              <input
                type="text"
                value={referralCode}
                onChange={(e) => setReferralCode(e.target.value.toUpperCase())}
                placeholder="e.g. MANI1234"
                className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-mono uppercase text-sm focus:outline-none focus:border-[#8B61F1] focus:bg-white transition-all"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl shadow-md hover:bg-[#D66311] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2 cursor-pointer"
          >
            {loading ? (
              <>
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                Creating Account...
              </>
            ) : (
              <>
                Create Traveller Account <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>

        </form>

        {/* DIVIDER */}
        <div className="relative flex items-center justify-center">
          <div className="border-t border-gray-200 w-full"></div>
          <span className="bg-white px-3 text-xs font-bold text-gray-400 uppercase tracking-wider absolute">OR</span>
        </div>

        {/* SOCIAL SIGN UP */}
        <button
          type="button"
          onClick={handleGoogleSignIn}
          className="w-full py-3 border border-gray-200 rounded-xl font-bold text-sm text-gray-700 hover:bg-gray-50 flex items-center justify-center gap-3 transition-all"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z" />
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z" />
          </svg>
          Continue with Google
        </button>

        {/* AGENT OPTION */}
        <div className="p-4 bg-purple-50 rounded-2xl border border-purple-100 flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-[#8B61F1]">Are you a local guide?</p>
            <p className="text-xs text-gray-600">Register as a verified TravelVibe Agent</p>
          </div>
          <Link
            to="/agent/signup"
            className="px-3 py-1.5 bg-[#8B61F1] text-white text-xs font-bold rounded-lg shadow-xs hover:bg-purple-700"
          >
            Apply Now
          </Link>
        </div>

        {/* FOOTER NAV */}
        <div className="pt-2 text-center text-sm font-semibold text-gray-600">
          Already have an account?{' '}
          <Link to="/login" className="text-[#E8741F] font-bold hover:underline">
            Log In
          </Link>
        </div>

      </div>
    </div>
  );
}
