import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';

const DEFAULT_TAGS = [
  'Wildlife Expert',
  'Photography Tours',
  'Family-Friendly',
  'Solo Traveller Safe',
  'Adventure/Trekking',
  'Cultural & Heritage',
  'Budget-Friendly',
  'Culinary & Food Walks',
  'Eco & Sustainable',
  'Bird Watching',
  'Spiritual & Temple Tours',
];

export default function Settings() {
  const [tags, setTags] = useState(DEFAULT_TAGS);
  const [newTag, setNewTag] = useState('');
  const [referralDiscount, setReferralDiscount] = useState(10);
  const [repeatDiscount, setRepeatDiscount] = useState(5);
  const [loading, setLoading] = useState(true);
  const [savingTags, setSavingTags] = useState(false);
  const [savingLoyalty, setSavingLoyalty] = useState(false);

  const { toast } = useToast();

  useEffect(() => {
    fetchSettings();

    const channel = supabase
      .channel('app_settings_changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'app_settings' }, () => {
        fetchSettings();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  async function fetchSettings() {
    try {
      setLoading(true);
      const { data, error } = await supabase.from('app_settings').select('*');
      if (error) {
        // Table may not be ready yet or empty, use fallback defaults
        console.warn('app_settings fetch error:', error.message);
        return;
      }

      if (data && data.length > 0) {
        const tagsRow = data.find((r) => r.key === 'specialization_tags_master');
        if (tagsRow && Array.isArray(tagsRow.value)) {
          setTags(tagsRow.value);
        }

        const loyaltyRow = data.find((r) => r.key === 'loyalty_discounts');
        if (loyaltyRow && typeof loyaltyRow.value === 'object') {
          if (loyaltyRow.value.referral_discount_percent !== undefined) {
            setReferralDiscount(Number(loyaltyRow.value.referral_discount_percent));
          }
          if (loyaltyRow.value.repeat_booking_discount_percent !== undefined) {
            setRepeatDiscount(Number(loyaltyRow.value.repeat_booking_discount_percent));
          }
        }
      }
    } catch (err) {
      console.error('Error fetching settings:', err);
    } finally {
      setLoading(false);
    }
  }

  function handleAddTag(e) {
    e?.preventDefault();
    const trimmed = newTag.trim();
    if (!trimmed) return;
    if (tags.some((t) => t.toLowerCase() === trimmed.toLowerCase())) {
      toast(`Tag "${trimmed}" already exists`, 'error');
      return;
    }
    setTags([...tags, trimmed]);
    setNewTag('');
  }

  function handleRemoveTag(tagToRemove) {
    setTags(tags.filter((t) => t !== tagToRemove));
  }

  async function handleSaveTags() {
    setSavingTags(true);
    try {
      const { error } = await supabase.from('app_settings').upsert({
        key: 'specialization_tags_master',
        value: tags,
        updated_at: new Date().toISOString(),
      });

      if (error) throw error;
      toast('Specialization tags saved successfully!', 'success');
    } catch (err) {
      console.error('Error saving tags:', err);
      toast(err.message || 'Failed to save tags to database', 'error');
    } finally {
      setSavingTags(false);
    }
  }

  async function handleSaveLoyalty() {
    setSavingLoyalty(true);
    try {
      const { error } = await supabase.from('app_settings').upsert({
        key: 'loyalty_discounts',
        value: {
          referral_discount_percent: Number(referralDiscount),
          repeat_booking_discount_percent: Number(repeatDiscount),
        },
        updated_at: new Date().toISOString(),
      });

      if (error) throw error;
      toast('Loyalty discount settings saved successfully!', 'success');
    } catch (err) {
      console.error('Error saving loyalty discounts:', err);
      toast(err.message || 'Failed to save loyalty settings', 'error');
    } finally {
      setSavingLoyalty(false);
    }
  }

  return (
    <div className="page" style={{ maxWidth: 1000, margin: '0 auto' }}>
      <div className="page-header">
        <div>
          <h1 className="page-title">Application Settings</h1>
          <p className="page-subtitle">Configure master specialization tags, loyalty discounts, and system preferences.</p>
        </div>
      </div>

      {loading ? (
        <div style={{ padding: 40, textAlign: 'center', color: 'var(--ink-soft)' }}>
          Loading application settings...
        </div>
      ) : (
        <div style={{ display: 'grid', gap: 24 }}>
          
          {/* SECTION 1: GUIDE SPECIALIZATION TAGS */}
          <div className="card" style={{ padding: 24 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <div>
                <h2 style={{ fontSize: 18, fontWeight: 800, margin: '0 0 4px', color: 'var(--ink)' }}>
                  🏷️ Guide Specialization Tags
                </h2>
                <p style={{ margin: 0, fontSize: 13, color: 'var(--ink-soft)' }}>
                  Master list of allowed specialization tags available to agents during profile editing and to travellers for filtering.
                </p>
              </div>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleSaveTags}
                disabled={savingTags}
                style={{ padding: '8px 18px', fontSize: 13 }}
              >
                {savingTags ? 'Saving...' : 'Save Tags'}
              </button>
            </div>

            {/* Add tag input form */}
            <form onSubmit={handleAddTag} style={{ display: 'flex', gap: 10, marginBottom: 20 }}>
              <input
                type="text"
                className="form-input"
                placeholder="Enter new specialization tag (e.g. Scuba Diving Guide, Heritage Walks)..."
                value={newTag}
                onChange={(e) => setNewTag(e.target.value)}
                style={{ flex: 1 }}
              />
              <button type="submit" className="btn btn-secondary" style={{ whiteSpace: 'nowrap' }}>
                + Add Tag
              </button>
            </form>

            {/* Tag Pills Display */}
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, minHeight: 60, padding: 12, background: 'var(--paper)', borderRadius: 12, border: '1px solid var(--line)' }}>
              {tags.length === 0 ? (
                <div style={{ color: 'var(--ink-soft)', fontSize: 13, padding: 8 }}>No tags configured. Add some above!</div>
              ) : (
                tags.map((tag, idx) => (
                  <span
                    key={idx}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 6,
                      padding: '6px 12px',
                      background: '#FFFFFF',
                      border: '1px solid #E2E8F0',
                      borderRadius: 20,
                      fontSize: 13,
                      fontWeight: 700,
                      color: '#1E293B',
                      boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                    }}
                  >
                    <span>{tag}</span>
                    <button
                      type="button"
                      onClick={() => handleRemoveTag(tag)}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        cursor: 'pointer',
                        color: '#94A3B8',
                        padding: 0,
                        fontSize: 14,
                        lineHeight: 1,
                        display: 'flex',
                        alignItems: 'center',
                      }}
                      title="Remove tag"
                    >
                      ×
                    </button>
                  </span>
                ))
              )}
            </div>
            <p style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 10 }}>
              💡 Total active tags: <strong>{tags.length}</strong>. Agents can select up to 4 tags from this master list.
            </p>
          </div>

          {/* SECTION 2: REPEAT TRAVELLER & REFERRAL DISCOUNTS */}
          <div className="card" style={{ padding: 24 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
              <div>
                <h2 style={{ fontSize: 18, fontWeight: 800, margin: '0 0 4px', color: 'var(--ink)' }}>
                  🎁 Loyalty & Referral Rewards Configuration
                </h2>
                <p style={{ margin: 0, fontSize: 13, color: 'var(--ink-soft)' }}>
                  Control discount percentages granted for referring new users and repeat bookings with the same guide.
                </p>
              </div>
              <button
                type="button"
                className="btn btn-primary"
                onClick={handleSaveLoyalty}
                disabled={savingLoyalty}
                style={{ padding: '8px 18px', fontSize: 13 }}
              >
                {savingLoyalty ? 'Saving...' : 'Save Discounts'}
              </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 20 }}>
              <div className="form-group">
                <label className="form-label" style={{ fontWeight: 700, fontSize: 13 }}>
                  Referral Discount (%)
                </label>
                <input
                  type="number"
                  min="0"
                  max="100"
                  step="1"
                  className="form-input"
                  value={referralDiscount}
                  onChange={(e) => setReferralDiscount(e.target.value)}
                  placeholder="e.g. 10"
                />
                <span style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 4, display: 'block' }}>
                  Awarded to referrer when a new user signs up with their code.
                </span>
              </div>

              <div className="form-group">
                <label className="form-label" style={{ fontWeight: 700, fontSize: 13 }}>
                  Repeat Booking Discount (%)
                </label>
                <input
                  type="number"
                  min="0"
                  max="100"
                  step="1"
                  className="form-input"
                  value={repeatDiscount}
                  onChange={(e) => setRepeatDiscount(e.target.value)}
                  placeholder="e.g. 5"
                />
                <span style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 4, display: 'block' }}>
                  Awarded when a traveller completes a prior booking and books the same guide again.
                </span>
              </div>
            </div>
          </div>

        </div>
      )}
    </div>
  );
}
