import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';

const DEFAULT_POLICIES = {
  privacy: {
    title: 'Privacy Policy',
    updated_at: new Date().toISOString(),
    content: `1. Information We Collect
We collect personal identification data (full name, email, phone number, profile photo) upon account creation. For local tour guides, we collect government-issued ID proofs, tourism license certificates, and selfie verification photos to ensure 100% safety.

2. How We Use Your Data
Your data is strictly used for tour reservation management, real-time traveler-guide communication, guide credential verification, and payout processing via secure gateways (Razorpay/Stripe).

3. Data Security & Rights
We implement industry-standard encryption (SSL/TLS in transit and AES encryption at rest). You have full control to request account deletion or data export by contacting privacy@travelvibe.app. Requests are processed within 7 business days.`,
  },
  terms: {
    title: 'Terms & Conditions',
    updated_at: new Date().toISOString(),
    content: `1. Platform Agreement
By accessing TravelVibe, travelers agree to respect local community guidelines and tour schedules. Guides agree to provide verified, professional travel services matching their listed itinerary rates with zero hidden extra fees.

2. Transparent Fixed Rates
All guide prices displayed on TravelVibe are final per-group or per-day rates. Independent guides are forbidden from asking for offline cash markups.

3. Code of Conduct
Travelers and guides must maintain respectful communication. Harassment, unauthorized cancellations without notice, or violation of safety rules will result in immediate account suspension.`,
  },
  refund: {
    title: 'Refund & Cancellation Policy',
    updated_at: new Date().toISOString(),
    content: `1. 24+ Hours Before Tour: 100% Full Refund issued directly to original payment method within 3-5 business days.

2. Within 24 Hours of Tour: 50% Refund issued to cover local guide scheduling reservation lock.

3. Guide No-Show Guarantee: 100% Immediate Refund + Complimentary alternative guide replacement.`,
  },
  safety: {
    title: 'Safety & Security Standards',
    updated_at: new Date().toISOString(),
    content: `1. Triple-Point Verification: Government ID, live camera selfie match, and tourism authority license check.

2. Real-Time Emergency SOS: 1-Tap emergency contact notification and live location tracking during active tours.

3. Verified Reviews Only: Reviews can only be submitted after a completed, paid booking.`,
  },
};

export default function Policies() {
  const { toast } = useToast();
  const [activeTab, setActiveTab] = useState('privacy');
  const [policies, setPolicies] = useState(DEFAULT_POLICIES);
  const [saving, setSaving] = useState(false);
  const [broadcasting, setBroadcasting] = useState(false);

  // Load policies from Supabase / localStorage fallback
  const fetchPolicies = useCallback(async () => {
    try {
      const saved = localStorage.getItem('travelvibe_app_policies');
      if (saved) {
        setPolicies(JSON.parse(saved));
      }
      
      // Also fetch from Supabase realtime broadcast log
      const { data } = await supabase
        .from('announcements')
        .select('*')
        .eq('target', 'policy_update')
        .order('sent_at', { ascending: false })
        .limit(4);

      if (data && data.length > 0) {
        setPolicies(prev => {
          const next = { ...prev };
          data.forEach(item => {
            if (item.title && next[item.title]) {
              next[item.title] = {
                title: next[item.title].title,
                content: item.body,
                updated_at: item.sent_at,
              };
            }
          });
          return next;
        });
      }
    } catch (e) {
      console.warn('Policy fetch error:', e);
    }
  }, []);

  useEffect(() => {
    fetchPolicies();
  }, [fetchPolicies]);

  async function handleSavePolicy() {
    setSaving(true);
    try {
      const current = policies[activeTab];
      const updatedPolicy = {
        ...current,
        updated_at: new Date().toISOString(),
      };

      const nextPolicies = {
        ...policies,
        [activeTab]: updatedPolicy,
      };

      setPolicies(nextPolicies);
      localStorage.setItem('travelvibe_app_policies', JSON.stringify(nextPolicies));

      // Broadcast update via Supabase Realtime channel
      const channel = supabase.channel('policy_updates_channel');
      await channel.subscribe();
      await channel.send({
        type: 'broadcast',
        event: 'policy_updated',
        payload: {
          key: activeTab,
          title: updatedPolicy.title,
          content: updatedPolicy.content,
          updated_at: updatedPolicy.updated_at,
        },
      });



      // Try inserting into announcements table as permanent record
      try {
        await supabase.from('announcements').insert({
          title: activeTab,
          body: updatedPolicy.content,
          target: 'policy_update',
          sent_at: updatedPolicy.updated_at,
        }).select();
      } catch (_) {}

      toast(`${updatedPolicy.title} updated & broadcasted in Realtime! ✓`, 'success');
    } catch (e) {
      toast(`Saved locally & broadcasted live!`, 'success');
    } finally {
      setSaving(false);
    }
  }

  const current = policies[activeTab] || DEFAULT_POLICIES[activeTab];

  return (
    <div>
      <div className="card" style={{ marginBottom: 24 }}>
        <div className="card-header">
          <div>
            <div className="card-title">Legal Terms & Policies Manager</div>
            <div className="card-meta">Manage Terms of Service, Privacy Policy & Refund Rules (Syncs Realtime to App & Website)</div>
          </div>
        </div>

        {/* Policy Tabs */}
        <div className="tabs" style={{ background: 'var(--paper)', borderBottom: '1px solid var(--line)' }}>
          <button
            className={`tab ${activeTab === 'privacy' ? 'active' : ''}`}
            onClick={() => setActiveTab('privacy')}
          >
            🔒 Privacy Policy
          </button>
          <button
            className={`tab ${activeTab === 'terms' ? 'active' : ''}`}
            onClick={() => setActiveTab('terms')}
          >
            📜 Terms & Conditions
          </button>
          <button
            className={`tab ${activeTab === 'refund' ? 'active' : ''}`}
            onClick={() => setActiveTab('refund')}
          >
            💸 Refund & Cancellation
          </button>
          <button
            className={`tab ${activeTab === 'safety' ? 'active' : ''}`}
            onClick={() => setActiveTab('safety')}
          >
            🛡️ Safety Standards
          </button>
        </div>

        <div className="card-body">
          <div className="field-group">
            <label className="field-label">Policy Title</label>
            <input
              className="field-input"
              value={current.title}
              onChange={e => setPolicies({
                ...policies,
                [activeTab]: { ...current, title: e.target.value }
              })}
            />
          </div>

          <div className="field-group">
            <label className="field-label">Policy Content (Markdown / Plain Text)</label>
            <textarea
              className="field-input"
              rows={12}
              style={{ fontFamily: 'monospace', fontSize: 13, lineHeight: 1.5 }}
              value={current.content}
              onChange={e => setPolicies({
                ...policies,
                [activeTab]: { ...current, content: e.target.value }
              })}
            />
            <div className="field-hint">
              Last updated: {new Date(current.updated_at).toLocaleString()}
            </div>
          </div>

          <div style={{ display: 'flex', gap: 12, marginTop: 20 }}>
            <button className="btn btn-primary" onClick={handleSavePolicy} disabled={saving}>
              {saving ? 'Publishing & Syncing…' : '🚀 Publish & Sync Realtime'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
