import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';

const TABS = [
  { key: 'privacy_policy', label: '🔒 Privacy Policy' },
  { key: 'terms_conditions', label: '📜 Terms & Conditions' },
  { key: 'refund_policy', label: '💸 Refund & Cancellation' },
];

export default function Policies() {
  const { toast } = useToast();
  const [activeTab, setActiveTab] = useState('privacy_policy');
  const [pages, setPages] = useState({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dbError, setDbError] = useState(null);

  // Load all legal pages from Supabase
  const fetchPages = useCallback(async () => {
    setLoading(true);
    setDbError(null);
    try {
      const { data, error } = await supabase
        .from('legal_pages')
        .select('*');
      if (error) throw error;
      const map = {};
      (data || []).forEach(p => { map[p.page_type] = p; });
      setPages(map);
    } catch (e) {
      console.error('legal_pages fetch error:', e);
      setDbError('Could not load legal pages from database. Run the SQL migration first.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchPages(); }, [fetchPages]);

  const current = pages[activeTab] || { page_type: activeTab, title: '', content: '', updated_at: null };

  function updateField(field, value) {
    setPages(prev => ({
      ...prev,
      [activeTab]: { ...(prev[activeTab] || {}), page_type: activeTab, [field]: value },
    }));
  }

  async function handleSave() {
    if (!current.title?.trim() || !current.content?.trim()) {
      toast('Title and content cannot be empty.', 'error');
      return;
    }
    setSaving(true);
    try {
      const { error } = await supabase
        .from('legal_pages')
        .upsert({
          page_type: activeTab,
          title: current.title.trim(),
          content: current.content.trim(),
          updated_at: new Date().toISOString(),
          updated_by: 'admin',
        }, { onConflict: 'page_type' });

      if (error) throw error;

      toast(`${current.title} saved to database and available to all apps ✓`, 'success');
      fetchPages();
    } catch (e) {
      console.error('Save legal page error:', e);
      toast(`Save failed: ${e.message}`, 'error');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div>
      <div className="card" style={{ marginBottom: 24 }}>
        <div className="card-header">
          <div>
            <div className="card-title">Legal Pages Manager</div>
            <div className="card-meta">
              Edit Privacy Policy, Terms &amp; Conditions, and Refund Policy.
              Content is saved to the database and automatically available in all apps.
            </div>
          </div>
          {Object.values(pages).length > 0 && (
            <span style={{ fontSize: 11, fontWeight: 700, background: '#d1fae5', color: '#065f46', borderRadius: 6, padding: '3px 10px' }}>
              ✓ {Object.values(pages).length} pages in database
            </span>
          )}
        </div>

        {dbError && (
          <div style={{ margin: '0 20px 16px', padding: '12px 16px', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: 8, fontSize: 13, color: '#991b1b' }}>
            <strong>Database Error:</strong> {dbError}
            <br /><span style={{ fontSize: 12, marginTop: 4, display: 'block' }}>
              Go to Supabase Dashboard → SQL Editor → paste and run the migration_production.sql file, then refresh.
            </span>
          </div>
        )}

        {/* Tab selector */}
        <div className="tabs" style={{ background: 'var(--paper)', borderBottom: '1px solid var(--line)' }}>
          {TABS.map(t => (
            <button
              key={t.key}
              className={`tab ${activeTab === t.key ? 'active' : ''}`}
              onClick={() => setActiveTab(t.key)}
            >
              {t.label}
              {pages[t.key] && (
                <span className="tab-count" style={{ background: '#d1fae5', color: '#065f46' }}>✓</span>
              )}
            </button>
          ))}
        </div>

        <div className="card-body">
          {loading ? (
            <Skeleton rows={6} cols={1} />
          ) : (
            <>
              <div className="field-group">
                <label className="field-label">Page Title</label>
                <input
                  className="field-input"
                  value={current.title || ''}
                  onChange={e => updateField('title', e.target.value)}
                  placeholder="e.g. Privacy Policy"
                />
              </div>

              <div className="field-group">
                <label className="field-label">Content (Markdown supported)</label>
                <textarea
                  className="field-input"
                  rows={20}
                  style={{ fontFamily: 'monospace', fontSize: 13, lineHeight: 1.6 }}
                  value={current.content || ''}
                  onChange={e => updateField('content', e.target.value)}
                  placeholder="Write the full policy content here…"
                />
                {current.updated_at && (
                  <div className="field-hint">
                    Last saved: {new Date(current.updated_at).toLocaleString()} by {current.updated_by || 'admin'}
                  </div>
                )}
                {!current.updated_at && (
                  <div className="field-hint" style={{ color: '#f59e0b' }}>
                    ⚠ This page has not been saved to the database yet.
                  </div>
                )}
              </div>

              <div style={{ display: 'flex', gap: 12, marginTop: 20 }}>
                <button
                  className="btn btn-primary"
                  onClick={handleSave}
                  disabled={saving || loading}
                >
                  {saving ? 'Saving…' : '💾 Save to Database'}
                </button>
                <button
                  className="btn btn-secondary"
                  onClick={fetchPages}
                  disabled={loading}
                >
                  ↺ Reload from DB
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
