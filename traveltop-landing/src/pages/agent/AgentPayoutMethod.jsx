import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase, getFreshUserId } from '../../supabaseClient';
import { useAuth } from '../../context/AuthContext';
import { verifyNameMatch } from '../../utils/nameMatching';
import {
  Building2,
  QrCode,
  ShieldCheck,
  AlertTriangle,
  CheckCircle2,
  ArrowLeft,
  Save,
  Lock,
  RefreshCw,
  Info,
} from 'lucide-react';

export default function AgentPayoutMethod() {
  const { user, profile } = useAuth();

  const [methodType, setMethodType] = useState('bank'); // 'bank' or 'upi'
  const [accountHolderName, setAccountHolderName] = useState('');
  const [bankAccountNumber, setBankAccountNumber] = useState('');
  const [confirmAccountNumber, setConfirmAccountNumber] = useState('');
  const [ifscCode, setIfscCode] = useState('');
  const [upiId, setUpiId] = useState('');

  const [existingMethod, setExistingMethod] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [successMsg, setSuccessMsg] = useState(null);

  const fetchPayoutMethod = async () => {
    const currentUserId = await getFreshUserId();
    if (!currentUserId) return;

    try {
      setLoading(true);
      const { data, error: err } = await supabase
        .from('agent_payout_methods')
        .select('*')
        .eq('agent_id', currentUserId)
        .maybeSingle();

      if (data) {
        setExistingMethod(data);
        setMethodType(data.method_type || 'bank');
        setAccountHolderName(data.account_holder_name || '');
        setBankAccountNumber(data.bank_account_number || '');
        setConfirmAccountNumber(data.bank_account_number || '');
        setIfscCode(data.ifsc_code || '');
        setUpiId(data.upi_id || '');
      } else {
        // Pre-fill holder name with verified profile name if available
        if (profile?.full_name) {
          setAccountHolderName(profile.full_name);
        }
      }
    } catch (e) {
      console.error('Error fetching payout method:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPayoutMethod();
  }, [user, profile]);

  const handleSave = async (e) => {
    e.preventDefault();
    setError(null);
    setSuccessMsg(null);

    const currentUserId = await getFreshUserId();
    if (!currentUserId) {
      setError('Please log in to save your payout method.');
      return;
    }

    if (!accountHolderName.trim()) {
      setError('Account holder name is required.');
      return;
    }

    if (methodType === 'bank') {
      if (!bankAccountNumber.trim()) {
        setError('Bank account number is required.');
        return;
      }
      if (bankAccountNumber.trim() !== confirmAccountNumber.trim()) {
        setError('Bank account numbers do not match.');
        return;
      }
      if (!ifscCode.trim() || ifscCode.trim().length < 11) {
        setError('Please enter a valid 11-character IFSC code.');
        return;
      }
    } else {
      if (!upiId.trim() || !upiId.includes('@')) {
        setError('Please enter a valid UPI ID (e.g. name@okhdfcbank).');
        return;
      }
    }

    setSaving(true);

    try {
      // Step: Perform Fuzzy Name Matching against verified Profile name
      const verifiedName = profile?.full_name || '';
      const matchResult = verifyNameMatch(accountHolderName, verifiedName);
      const isNameVerified = matchResult.verified;

      const payload = {
        agent_id: currentUserId,
        method_type: methodType,
        account_holder_name: accountHolderName.trim(),
        bank_account_number: methodType === 'bank' ? bankAccountNumber.trim() : null,
        ifsc_code: methodType === 'bank' ? ifscCode.trim().toUpperCase() : null,
        upi_id: methodType === 'upi' ? upiId.trim() : null,
        name_verified: isNameVerified,
        updated_at: new Date().toISOString(),
      };

      const { data, error: upsertErr } = await supabase
        .from('agent_payout_methods')
        .upsert(payload, { onConflict: 'agent_id' })
        .select()
        .single();

      if (upsertErr) throw upsertErr;

      setExistingMethod(data);

      if (isNameVerified) {
        setSuccessMsg(
          'Payout method saved and verified successfully! Your account is ready to receive staged trip releases.'
        );
      } else {
        setSuccessMsg(
          `Payout method saved. Notice: Name mismatch detected ("${accountHolderName.trim()}" vs verified ID "${verifiedName}"). This payout method has been flagged for Admin review before funds can be released.`
        );

        // Notify Admin of payout name mismatch
        try {
          await supabase.from('notifications').insert({
            user_id: currentUserId,
            title: 'Payout Name Mismatch Flagged',
            body: `Agent ${verifiedName} submitted payout name "${accountHolderName.trim()}" requiring manual admin verification.`,
            type: 'admin_review',
          });
        } catch (_) {}
      }
    } catch (err) {
      console.error('Error saving payout method:', err);
      setError(err.message || 'Failed to save payout method.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="pb-16 bg-[#F7F6FB] min-h-screen space-y-8">
      {/* HEADER */}
      <section className="bg-white border-b border-gray-100 py-8 px-4 sm:px-6 lg:px-8">
        <div className="max-w-3xl mx-auto space-y-2">
          <Link
            to="/agent/earnings"
            className="inline-flex items-center gap-1.5 text-xs font-bold text-gray-500 hover:text-gray-900 mb-2"
          >
            <ArrowLeft className="w-4 h-4" /> Back to Earnings
          </Link>
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-extrabold text-gray-900 tracking-tight">
                Payout Method & Bank Details
              </h1>
              <p className="text-sm font-semibold text-gray-500">
                Link your bank account or UPI ID to receive escrow payments for guided trips
              </p>
            </div>
            {existingMethod && (
              <span
                className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-black border self-start sm:self-auto ${
                  existingMethod.name_verified
                    ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                    : 'bg-amber-50 text-amber-800 border-amber-200 animate-pulse'
                }`}
              >
                {existingMethod.name_verified ? (
                  <>
                    <ShieldCheck className="w-4 h-4 text-emerald-600" /> Name Verified
                  </>
                ) : (
                  <>
                    <AlertTriangle className="w-4 h-4 text-amber-600" /> Pending Admin Review
                  </>
                )}
              </span>
            )}
          </div>
        </div>
      </section>

      <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 space-y-6">
        {/* COMPLIANCE NOTICE */}
        <div className="p-5 bg-gradient-to-br from-purple-50 to-indigo-50 rounded-2xl border border-purple-100 space-y-2">
          <div className="flex items-center gap-2">
            <Lock className="w-4 h-4 text-[#8B61F1]" />
            <h3 className="text-xs font-extrabold text-purple-900 uppercase tracking-wider">
              Fraud Prevention & Name Matching Policy
            </h3>
          </div>
          <p className="text-xs text-gray-600 font-medium leading-relaxed">
            To prevent fraud and comply with Indian payment settlement rules, the account holder
            name must match your verified identity document (<strong>{profile?.full_name || 'Your Name'}</strong>).
            Payout releases are held in escrow and released automatically only to verified payout
            methods.
          </p>
        </div>

        {/* ALERTS */}
        {successMsg && (
          <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm font-semibold flex items-start gap-3">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
            <div>{successMsg}</div>
          </div>
        )}

        {error && (
          <div className="p-4 rounded-2xl bg-rose-50 border border-rose-200 text-rose-800 text-sm font-semibold flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
            <div>{error}</div>
          </div>
        )}

        {/* MAIN FORM CARD */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 shadow-sm border border-gray-100 space-y-6">
          {/* METHOD TOGGLE */}
          <div className="space-y-2">
            <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider">
              Settlement Method
            </label>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setMethodType('bank')}
                className={`py-3.5 px-4 rounded-2xl font-extrabold text-xs flex items-center justify-center gap-2 border transition-all cursor-pointer ${
                  methodType === 'bank'
                    ? 'bg-purple-50 text-[#8B61F1] border-purple-300 shadow-xs'
                    : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
                }`}
              >
                <Building2 className="w-4 h-4" /> Bank Account (NEFT / IMPS)
              </button>
              <button
                type="button"
                onClick={() => setMethodType('upi')}
                className={`py-3.5 px-4 rounded-2xl font-extrabold text-xs flex items-center justify-center gap-2 border transition-all cursor-pointer ${
                  methodType === 'upi'
                    ? 'bg-purple-50 text-[#8B61F1] border-purple-300 shadow-xs'
                    : 'bg-gray-50 text-gray-600 border-gray-200 hover:bg-gray-100'
                }`}
              >
                <QrCode className="w-4 h-4" /> Instant UPI ID
              </button>
            </div>
          </div>

          <form onSubmit={handleSave} className="space-y-5">
            {/* ACCOUNT HOLDER NAME */}
            <div>
              <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                Account Holder Full Name (As per Bank Records)
              </label>
              <input
                type="text"
                required
                value={accountHolderName}
                onChange={(e) => setAccountHolderName(e.target.value)}
                placeholder="e.g. GANAPARTHI MANISH"
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-bold text-sm focus:outline-none focus:border-[#8B61F1]"
              />
              <p className="text-[11px] text-gray-400 mt-1">
                Must match your approved guide ID: <strong>{profile?.full_name || 'Loading...'}</strong>
              </p>
            </div>

            {/* CONDITIONAL BANK DETAILS */}
            {methodType === 'bank' ? (
              <div className="space-y-4 pt-2 border-t border-gray-100">
                <div>
                  <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                    Bank Account Number
                  </label>
                  <input
                    type="password"
                    required
                    value={bankAccountNumber}
                    onChange={(e) => setBankAccountNumber(e.target.value)}
                    placeholder="Enter full bank account number"
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-mono text-sm focus:outline-none focus:border-[#8B61F1]"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                    Confirm Bank Account Number
                  </label>
                  <input
                    type="text"
                    required
                    value={confirmAccountNumber}
                    onChange={(e) => setConfirmAccountNumber(e.target.value)}
                    placeholder="Re-enter bank account number"
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-mono text-sm focus:outline-none focus:border-[#8B61F1]"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                    IFSC Code
                  </label>
                  <input
                    type="text"
                    required
                    maxLength={11}
                    value={ifscCode}
                    onChange={(e) => setIfscCode(e.target.value.toUpperCase())}
                    placeholder="e.g. HDFC0001234"
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-mono uppercase text-sm focus:outline-none focus:border-[#8B61F1]"
                  />
                  <p className="text-[11px] text-gray-400 mt-1">
                    11-character code found on your cheque or bank passbook
                  </p>
                </div>
              </div>
            ) : (
              /* CONDITIONAL UPI DETAILS */
              <div className="space-y-4 pt-2 border-t border-gray-100">
                <div>
                  <label className="block text-xs font-bold text-gray-700 uppercase tracking-wider mb-1.5">
                    Virtual Payment Address (UPI ID)
                  </label>
                  <input
                    type="text"
                    required
                    value={upiId}
                    onChange={(e) => setUpiId(e.target.value)}
                    placeholder="e.g. yourname@okhdfcbank or 9876543210@paytm"
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl font-mono text-sm focus:outline-none focus:border-[#8B61F1]"
                  />
                  <p className="text-[11px] text-gray-400 mt-1">
                    Direct instant payouts via UPI Autopay / Razorpay Payouts
                  </p>
                </div>
              </div>
            )}

            <button
              type="submit"
              disabled={saving}
              className="w-full py-4 bg-[#8B61F1] text-white font-extrabold text-sm rounded-xl shadow-md hover:bg-purple-700 active:scale-[0.99] transition-all disabled:opacity-50 flex items-center justify-center gap-2 cursor-pointer"
            >
              {saving ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" /> Verifying & Saving...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" /> Save & Verify Payout Method
                </>
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
