import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { supabase } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { User, Mail, Lock, Phone, ShieldCheck, FileText, CheckCircle2, AlertCircle, ArrowRight, ArrowLeft } from 'lucide-react';

export default function AgentSignup() {
  const [step, setStep] = useState(1);

  // Step 1
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');

  // Step 2
  const [bio, setBio] = useState('');
  const [experience, setExperience] = useState('3');
  const [pricePerDay, setPricePerDay] = useState('1500');
  const [languages, setLanguages] = useState('English, Hindi');
  const [placesCovered, setPlacesCovered] = useState('Munnar, Alleppey');

  // Step 3
  const [docUrl, setDocUrl] = useState('');
  const [mealsIncluded, setMealsIncluded] = useState(false);
  const [stayIncluded, setStayIncluded] = useState(false);
  const [transportIncluded, setTransportIncluded] = useState(false);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [successNotice, setSuccessNotice] = useState(null);

  const navigate = useNavigate();
  const { refreshProfile } = useAuth();

  const handleAgentRegistration = async (e) => {
    e.preventDefault();

    if (!fullName || !email || !password) {
      setError('Please fill in all required fields.');
      return;
    }

    setLoading(true);
    setError(null);
    setSuccessNotice(null);

    try {
      // 1. Supabase Auth Sign Up
      const { data, error: signUpErr } = await supabase.auth.signUp({
        email: email.trim(),
        password: password.trim(),
        options: {
          data: {
            full_name: fullName.trim(),
            phone: phone.trim(),
            role: 'agent',
          },
        },
      });

      if (signUpErr) throw signUpErr;

      const userId = data.user?.id;
      if (userId) {
        // 2. Insert into profiles table
        await supabase.from('profiles').upsert({
          id: userId,
          role: 'agent',
          full_name: fullName.trim(),
          phone: phone.trim(),
          created_at: new Date().toISOString(),
        });

        // 3. Insert into agent_details table
        const langArr = languages.split(',').map((l) => l.trim()).filter(Boolean);
        const placesArr = placesCovered.split(',').map((p) => p.trim()).filter(Boolean);

        await supabase.from('agent_details').upsert({
          id: userId,
          bio: bio.trim() || 'Local guide ready for custom tours.',
          years_experience: parseInt(experience) || 2,
          price_per_day: parseFloat(pricePerDay) || 1500,
          languages: langArr,
          places_covered: placesArr,
          meals_included: mealsIncluded,
          accommodation_included: stayIncluded,
          transport_included: transportIncluded,
          verified: false, // Pending admin approval
          verification_doc_url: docUrl.trim() || 'https://via.placeholder.com/400x300?text=Verification+Document',
          rating_avg: 5.0,
          review_count: 0,
        });
      }

      if (data.session) {
        await refreshProfile(userId);
        navigate('/agent/pending', { replace: true });
      } else {
        setSuccessNotice(
          `Application submitted! A verification link was sent to ${email}. Please verify your email, then sign in to check your application status.`
        );
      }
    } catch (err) {
      console.error('Agent signup error:', err);
      const errStr = (err.message || '').toLowerCase();
      if (errStr.includes('rate limit') || errStr.includes('429') || errStr.includes('over_email_send_rate_limit')) {
        setError(
          'Supabase email rate limit reached (free default SMTP max limit). Please turn OFF "Confirm email" in Supabase Dashboard -> Authentication -> Providers -> Email, or wait an hour.'
        );
      } else {
        setError(err.message || 'Registration failed.');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8 bg-[#F7F6FB]">
      <div className="max-w-xl w-full bg-white rounded-3xl p-8 shadow-xl border border-gray-100 space-y-6">
        
        {/* HEADER */}
        <div className="text-center space-y-2">
          <div className="w-12 h-12 bg-purple-100 rounded-2xl flex items-center justify-center mx-auto text-[#8B61F1]">
            <ShieldCheck className="w-6 h-6" />
          </div>
          <h2 className="text-2xl font-extrabold text-gray-900 tracking-tight">Become a Verified Local Guide</h2>
          <p className="text-sm font-semibold text-gray-500">3-Step Registration to join the TravelVibe Agent Network</p>
        </div>

        {/* STEP PROGRESS BAR */}
        <div className="flex items-center justify-between border-b border-gray-100 pb-4">
          <div className={`flex items-center gap-2 font-bold text-xs ${step >= 1 ? 'text-[#8B61F1]' : 'text-gray-400'}`}>
            <span className="w-6 h-6 rounded-full bg-purple-100 flex items-center justify-center">1</span> Basic Info
          </div>
          <div className={`flex items-center gap-2 font-bold text-xs ${step >= 2 ? 'text-[#8B61F1]' : 'text-gray-400'}`}>
            <span className="w-6 h-6 rounded-full bg-purple-100 flex items-center justify-center">2</span> Guide Profile
          </div>
          <div className={`flex items-center gap-2 font-bold text-xs ${step >= 3 ? 'text-[#8B61F1]' : 'text-gray-400'}`}>
            <span className="w-6 h-6 rounded-full bg-purple-100 flex items-center justify-center">3</span> Verification
          </div>
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
              to="/agent/login"
              className="inline-block mt-2 px-4 py-2 bg-[#8B61F1] text-white text-xs font-bold rounded-xl hover:bg-purple-700 transition-all"
            >
              Go to Agent Sign In
            </Link>
          </div>
        )}

        <form onSubmit={handleAgentRegistration} className="space-y-4">
          
          {/* STEP 1: BASIC DETAILS */}
          {step === 1 && (
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Full Name</label>
                <input
                  type="text"
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="e.g. Ramesh Kumar"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Email Address</label>
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="ramesh.guide@gmail.com"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Phone Number</label>
                <input
                  type="tel"
                  required
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+91 98765 43210"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Password</label>
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="At least 6 characters"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <button
                type="button"
                onClick={() => {
                  if (!fullName || !email || !password) {
                    setError('Please fill in required fields.');
                    return;
                  }
                  setError(null);
                  setStep(2);
                }}
                className="w-full py-3.5 bg-[#8B61F1] text-white font-bold text-sm rounded-xl shadow-md hover:bg-purple-700 flex items-center justify-center gap-2"
              >
                Next: Guide Details <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          )}

          {/* STEP 2: PROFILE DETAILS */}
          {step === 2 && (
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Guide Bio / Summary</label>
                <textarea
                  rows={3}
                  value={bio}
                  onChange={(e) => setBio(e.target.value)}
                  placeholder="Describe your guiding experience, local expertise, and trip specializations..."
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Years Experience</label>
                  <input
                    type="number"
                    value={experience}
                    onChange={(e) => setExperience(e.target.value)}
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Daily Rate (₹)</label>
                  <input
                    type="number"
                    value={pricePerDay}
                    onChange={(e) => setPricePerDay(e.target.value)}
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Places Covered (comma separated)</label>
                <input
                  type="text"
                  value={placesCovered}
                  onChange={(e) => setPlacesCovered(e.target.value)}
                  placeholder="e.g. Munnar, Alleppey, Cochin"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Languages Spoken (comma separated)</label>
                <input
                  type="text"
                  value={languages}
                  onChange={(e) => setLanguages(e.target.value)}
                  placeholder="e.g. English, Hindi, Malayalam"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setStep(1)}
                  className="w-1/3 py-3.5 bg-gray-100 text-gray-700 font-bold text-sm rounded-xl flex items-center justify-center gap-1"
                >
                  <ArrowLeft className="w-4 h-4" /> Back
                </button>
                <button
                  type="button"
                  onClick={() => setStep(3)}
                  className="w-2/3 py-3.5 bg-[#8B61F1] text-white font-bold text-sm rounded-xl shadow-md hover:bg-purple-700 flex items-center justify-center gap-2"
                >
                  Next: Upload ID <ArrowRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}

          {/* STEP 3: DOCUMENT UPLOAD & SUBMIT */}
          {step === 3 && (
            <div className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                  Govt ID / Verification Document URL or Reference
                </label>
                <input
                  type="text"
                  value={docUrl}
                  onChange={(e) => setDocUrl(e.target.value)}
                  placeholder="Paste URL or document ID (Aadhaar, Passport, etc.)"
                  className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#8B61F1]"
                />
              </div>

              <div className="space-y-2 pt-2">
                <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider">Default Included Services</label>
                <div className="space-y-2">
                  <label className="flex items-center gap-2.5 text-xs font-semibold text-gray-700 cursor-pointer">
                    <input type="checkbox" checked={mealsIncluded} onChange={(e) => setMealsIncluded(e.target.checked)} className="rounded text-[#8B61F1]" />
                    Meals Included in Daily Rate
                  </label>
                  <label className="flex items-center gap-2.5 text-xs font-semibold text-gray-700 cursor-pointer">
                    <input type="checkbox" checked={stayIncluded} onChange={(e) => setStayIncluded(e.target.checked)} className="rounded text-[#8B61F1]" />
                    Stay / Accommodation Included
                  </label>
                  <label className="flex items-center gap-2.5 text-xs font-semibold text-gray-700 cursor-pointer">
                    <input type="checkbox" checked={transportIncluded} onChange={(e) => setTransportIncluded(e.target.checked)} className="rounded text-[#8B61F1]" />
                    Local Transport Included
                  </label>
                </div>
              </div>

              <div className="flex gap-2 pt-4">
                <button
                  type="button"
                  onClick={() => setStep(2)}
                  className="w-1/3 py-3.5 bg-gray-100 text-gray-700 font-bold text-sm rounded-xl flex items-center justify-center gap-1 hover:bg-gray-200"
                >
                  <ArrowLeft className="w-4 h-4" /> Back
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="w-2/3 py-3.5 bg-[#8B61F1] text-white font-extrabold text-sm rounded-xl shadow-md hover:bg-purple-700 active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2"
                >
                  {loading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                      Submitting Application...
                    </>
                  ) : (
                    'Complete Agent Application'
                  )}
                </button>
              </div>
            </div>
          )}


        </form>

        <div className="pt-2 text-center text-sm font-semibold text-gray-600">
          Already an approved agent?{' '}
          <Link to="/agent/login" className="text-[#8B61F1] font-bold hover:underline">
            Agent Sign In
          </Link>
        </div>

      </div>
    </div>
  );
}
