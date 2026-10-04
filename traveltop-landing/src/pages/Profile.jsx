import React, { useState, useEffect } from 'react';
import { supabase, getFreshUserId } from '../supabaseClient';
import { useAuth } from '../context/AuthContext';
import { useLanguage } from '../context/LanguageContext';
import { User, Phone, Mail, MapPin, ShieldCheck, CheckCircle2, AlertCircle, Save, Gift, Share2, Copy, Sparkles, Globe } from 'lucide-react';

export default function Profile() {
  const { user, profile, refreshProfile } = useAuth();
  const { language, setLanguage, t, supportedLanguages } = useLanguage();

  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [photoUrl, setPhotoUrl] = useState('');
  const [emergencyContact, setEmergencyContact] = useState('');
  const [address, setAddress] = useState('');
  const [loyaltyRewards, setLoyaltyRewards] = useState([]);
  const [copied, setCopied] = useState(false);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (profile) {
      setFullName(profile.full_name || '');
      setPhone(profile.phone || '');
      setPhotoUrl(profile.photo_url || '');
      setEmergencyContact(profile.emergency_contact || '');
      if (typeof profile.delivery_address === 'string') {
        setAddress(profile.delivery_address);
      } else if (profile.delivery_address?.street) {
        setAddress(profile.delivery_address.street);
      }
    }

    if (user?.id) {
      fetchLoyaltyRewards(user.id);
    }
  }, [profile, user]);

  const fetchLoyaltyRewards = async (userId) => {
    try {
      const { data } = await supabase
        .from('loyalty_rewards')
        .select('*')
        .eq('traveller_id', userId)
        .order('created_at', { ascending: false });
      setLoyaltyRewards(data || []);
    } catch (_) {}
  };

  const handleCopyReferral = () => {
    const code = profile?.referral_code || 'TRAVELVIBE';
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  const handleShareReferral = async () => {
    const code = profile?.referral_code || 'TRAVELVIBE';
    const text = `Join me on TravelVibe! Book verified local tour guides across India. Use my referral code ${code} for 10% off your first trip: https://travelvibe.in/signup`;
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Join TravelVibe',
          text,
          url: 'https://travelvibe.in/signup',
        });
      } catch (_) {}
    } else {
      handleCopyReferral();
    }
  };

  const handleSaveProfile = async (e) => {
    e.preventDefault();

    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      setError('Please log in to save settings.');
      return;
    }

    setSaving(true);
    setMsg(null);
    setError(null);

    try {
      const { error: updateErr } = await supabase
        .from('profiles')
        .update({
          full_name: fullName.trim(),
          phone: phone.trim(),
          photo_url: photoUrl.trim(),
          emergency_contact: emergencyContact.trim(),
          delivery_address: { street: address.trim() },
        })
        .eq('id', currentUserId);

      if (updateErr) throw updateErr;

      await refreshProfile();
      setMsg('Profile updated successfully!');
    } catch (err) {
      console.error('Error updating profile:', err);
      setError(err.message || 'Failed to update profile.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto space-y-2">
          <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">Account Settings</h1>
          <p className="text-sm font-semibold text-gray-500">Manage your profile details and emergency contact preferences</p>
        </div>
      </section>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-xl border border-gray-100 space-y-6">
          
          {/* USER BADGE */}
          <div className="flex items-center gap-4 pb-6 border-b border-gray-100">
            {photoUrl ? (
              <img src={photoUrl} alt="Avatar" className="w-16 h-16 rounded-2xl object-cover border-2 border-orange-200" />
            ) : (
              <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-[#E8741F] to-[#8B61F1] text-white flex items-center justify-center font-extrabold text-2xl">
                {fullName?.charAt(0) || user?.email?.charAt(0) || 'U'}
              </div>
            )}
            <div>
              <h2 className="font-extrabold text-gray-900 text-lg">{fullName || 'TravelVibe User'}</h2>
              <p className="text-xs font-semibold text-gray-500">{user?.email}</p>
              <span className="inline-block mt-1 px-2.5 py-0.5 bg-orange-100 text-[#E8741F] text-[10px] font-extrabold uppercase rounded-full">
                {profile?.role || 'traveller'}
              </span>
            </div>
          </div>

          {/* SUCCESS / ERROR ALERTS */}
          {msg && (
            <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm font-semibold flex items-center gap-2">
              <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
              <div>{msg}</div>
            </div>
          )}

          {error && (
            <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-rose-800 text-sm font-semibold flex items-center gap-2">
              <AlertCircle className="w-5 h-5 text-rose-600 shrink-0" />
              <div>{error}</div>
            </div>
          )}

          {/* REFERRAL CODE & LOYALTY CARD (FEATURE 4) */}
          <div className="p-5 bg-gradient-to-br from-purple-50 via-indigo-50 to-orange-50 rounded-2xl border-2 border-purple-100 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex items-center gap-2">
                <Gift className="w-5 h-5 text-[#8B61F1]" />
                <h3 className="font-extrabold text-sm text-gray-900">Your Referral Code</h3>
              </div>
              <p className="text-xs text-gray-600 font-medium">
                Share this code with friends. When they sign up, they get a discount, and you get 10% off your next guide booking!
              </p>
              <div className="pt-2 flex items-center gap-2">
                <span className="font-mono text-base font-extrabold tracking-wider bg-white px-3.5 py-1.5 rounded-xl border border-purple-200 text-[#8B61F1] shadow-xs">
                  {profile?.referral_code || 'TVIBE2026'}
                </span>
                <button
                  type="button"
                  onClick={handleCopyReferral}
                  className="px-3 py-1.5 bg-white border border-gray-200 text-xs font-bold rounded-xl hover:bg-gray-50 flex items-center gap-1 text-gray-700 shadow-xs cursor-pointer"
                >
                  <Copy className="w-3.5 h-3.5" />
                  {copied ? 'Copied!' : 'Copy'}
                </button>
              </div>
            </div>

            <button
              type="button"
              onClick={handleShareReferral}
              className="px-5 py-2.5 bg-[#8B61F1] text-white text-xs font-extrabold rounded-xl hover:bg-purple-700 shadow-sm flex items-center gap-1.5 shrink-0 cursor-pointer"
            >
              <Share2 className="w-4 h-4" /> Share Code
            </button>
          </div>

          {/* ACTIVE LOYALTY REWARDS (FEATURE 4) */}
          {loyaltyRewards.length > 0 && (
            <div className="p-5 bg-emerald-50/60 rounded-2xl border border-emerald-200 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-xs font-extrabold text-emerald-900 uppercase tracking-wider flex items-center gap-1.5">
                  <Sparkles className="w-4 h-4 text-emerald-600" /> My Loyalty Rewards
                </h3>
                <span className="text-[10px] font-extrabold text-emerald-700 bg-emerald-100 px-2.5 py-0.5 rounded-full">
                  {loyaltyRewards.filter((r) => !r.is_used).length} Active
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                {loyaltyRewards.map((rew) => (
                  <div
                    key={rew.id}
                    className={`p-3 rounded-xl border flex items-center justify-between ${
                      rew.is_used
                        ? 'bg-gray-50 border-gray-200 opacity-60'
                        : 'bg-white border-emerald-300 shadow-xs'
                    }`}
                  >
                    <div>
                      <p className="text-xs font-extrabold text-gray-900">{rew.description}</p>
                      <span className="text-[10px] font-bold text-gray-400">
                        {rew.is_used ? 'Redeemed' : 'Ready to apply on checkout'}
                      </span>
                    </div>
                    <span className="text-xs font-black text-emerald-600">
                      {rew.discount_percent}% OFF
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* FORM */}
          <form onSubmit={handleSaveProfile} className="space-y-4">
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Full Name</label>
              <div className="relative">
                <User className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
                <input
                  type="text"
                  required
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F]"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Phone Number</label>
              <div className="relative">
                <Phone className="w-5 h-5 absolute left-3.5 top-3.5 text-gray-400" />
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+91 98765 43210"
                  className="w-full pl-11 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F]"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Photo Image URL</label>
              <input
                type="url"
                value={photoUrl}
                onChange={(e) => setPhotoUrl(e.target.value)}
                placeholder="https://..."
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F]"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">Emergency Contact Phone</label>
              <input
                type="tel"
                value={emergencyContact}
                onChange={(e) => setEmergencyContact(e.target.value)}
                placeholder="Emergency contact number for safety tracking"
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F]"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                {t('delivery_address', 'Default Shipping Address')}
              </label>
              <textarea
                rows={2}
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                placeholder="Your home or delivery address"
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-medium text-sm focus:outline-none focus:border-[#E8741F]"
              />
            </div>

            {/* REGIONAL LANGUAGE PREFERENCE SELECTOR */}
            <div className="pt-2 pb-1 border-t border-gray-100">
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                <Globe className="w-4 h-4 text-[#E8741F]" />
                {t('language_preference', 'Language Preference')}
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                {supportedLanguages.map((l) => (
                  <button
                    key={l.code}
                    type="button"
                    onClick={() => setLanguage(l.code)}
                    className={`py-2.5 px-3 rounded-xl text-xs font-extrabold flex flex-col items-center justify-center border cursor-pointer transition-all ${
                      language === l.code
                        ? 'bg-gradient-to-r from-[#E8741F] to-[#D66311] text-white border-transparent shadow-md shadow-orange-500/20'
                        : 'bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100'
                    }`}
                  >
                    <span>{l.native}</span>
                    <span className="text-[10px] opacity-75 font-normal">{l.label}</span>
                  </button>
                ))}
              </div>
            </div>

            <button
              type="submit"
              disabled={saving}
              className="w-full py-3.5 bg-[#E8741F] text-white font-bold text-sm rounded-xl shadow-md hover:bg-[#D66311] active:scale-[0.98] transition-all disabled:opacity-50 flex items-center justify-center gap-2 cursor-pointer"
            >
              <Save className="w-4 h-4" />
              {saving ? 'Saving Changes...' : t('save_changes', 'Save Profile Settings')}
            </button>
          </form>

        </div>
      </div>
    </div>
  );
}
