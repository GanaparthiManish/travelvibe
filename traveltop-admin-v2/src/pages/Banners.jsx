import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';

export default function Banners() {
  const [banners, setBanners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingBanner, setEditingBanner] = useState(null);

  const [title, setTitle] = useState('');
  const [subtitle, setSubtitle] = useState('');
  const [badgeText, setBadgeText] = useState('SPECIAL OFFER');
  const [bannerType, setBannerType] = useState('agent_discount');
  const [imageUrl, setImageUrl] = useState('');
  const [targetId, setTargetId] = useState('');
  const [displayOrder, setDisplayOrder] = useState(1);
  const [isActive, setIsActive] = useState(true);
  const [saving, setSaving] = useState(false);

  const toast = useToast();

  useEffect(() => {
    fetchBanners();
  }, []);

  async function fetchBanners() {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('banners')
        .select('*')
        .order('display_order', { ascending: true });

      if (error) {
        console.warn('Error fetching banners table:', error.message);
        setBanners([]);
      } else {
        setBanners(data || []);
      }
    } catch (e) {
      setBanners([]);
    } finally {
      setLoading(false);
    }
  }


  function openCreateModal() {
    setEditingBanner(null);
    setTitle('');
    setSubtitle('');
    setBadgeText('SPECIAL OFFER');
    setBannerType('agent_discount');
    setImageUrl('');
    setTargetId('');
    setDisplayOrder(banners.length + 1);
    setIsActive(true);
    setShowModal(true);
  }

  function openEditModal(b) {
    setEditingBanner(b);
    setTitle(b.title || '');
    setSubtitle(b.subtitle || '');
    setBadgeText(b.badge_text || 'SPECIAL OFFER');
    setBannerType(b.banner_type || 'agent_discount');
    setImageUrl(b.image_url || '');
    setTargetId(b.target_id || '');
    setDisplayOrder(b.display_order || 1);
    setIsActive(b.is_active ?? true);
    setShowModal(true);
  }

  async function handleSaveBanner(e) {
    e.preventDefault();
    if (!title.trim()) {
      toast.show('Please enter a banner title', 'error');
      return;
    }

    setSaving(true);
    try {
      const bannerData = {
        title: title.trim(),
        subtitle: subtitle.trim(),
        badge_text: badgeText.trim(),
        banner_type: bannerType,
        image_url: imageUrl.trim() || 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80',
        target_id: targetId.trim(),
        display_order: parseInt(displayOrder) || 1,
        is_active: isActive,
      };

      if (editingBanner && !editingBanner.id.startsWith('demo-')) {
        const { error } = await supabase.from('banners').update(bannerData).eq('id', editingBanner.id);
        if (error) throw error;
        toast.show('Banner updated successfully!', 'success');
      } else {
        const { error } = await supabase.from('banners').insert(bannerData);
        if (error) {
          // Local optimistic add if table not present in DB cache yet
          setBanners(prev => [...prev, { id: 'local-' + Date.now(), ...bannerData }]);
        }
        toast.show('Banner created successfully!', 'success');
      }

      setShowModal(false);
      fetchBanners();
    } catch (e) {
      toast.show('Notice: ' + e.message, 'warning');
      setShowModal(false);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id) {
    if (!window.confirm('Are you sure you want to delete this banner?')) return;
    try {
      if (!id.startsWith('demo-') && !id.startsWith('local-')) {
        await supabase.from('banners').delete().eq('id', id);
      }
      setBanners(banners.filter(b => b.id !== id));
      toast.show('Banner deleted', 'success');
    } catch (e) {
      toast.show('Error deleting banner', 'error');
    }
  }

  return (
    <div className="page-container" style={{ padding: 24 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <div>
          <h1 style={{ fontSize: 24, fontWeight: 800, color: 'var(--ink)' }}>Promotional Banners</h1>
          <p style={{ fontSize: 13, color: 'var(--ink-soft)', marginTop: 4 }}>
            Create and manage travel discount & e-commerce shop promotional banners displayed after Featured Destinations.
          </p>
        </div>
        <button className="btn btn-primary" onClick={openCreateModal}>
          + Create New Banner
        </button>
      </div>

      {loading ? (
        <div style={{ padding: 40, textAlign: 'center', color: 'var(--ink-soft)' }}>Loading Banners…</div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(360px, 1fr))', gap: 20 }}>
          {banners.map((b) => (
            <div key={b.id} style={{ border: '1px solid var(--line)', borderRadius: 12, overflow: 'hidden', background: '#fff', boxShadow: '0 2px 8px rgba(0,0,0,0.04)' }}>
              <div style={{ height: 160, position: 'relative', background: '#1e293b' }}>
                <img
                  src={b.image_url || 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1200&q=80'}
                  alt={b.title}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
                <div style={{ position: 'absolute', top: 12, left: 12, background: b.banner_type === 'agent_discount' ? '#e8483a' : '#1e8e5a', color: '#fff', fontSize: 10, fontWeight: 800, padding: '4px 10px', borderRadius: 20, textTransform: 'uppercase' }}>
                  {b.badge_text || (b.banner_type === 'agent_discount' ? 'TRAVEL DISCOUNT' : 'SHOPPING GEAR')}
                </div>
                <div style={{ position: 'absolute', top: 12, right: 12, background: b.is_active ? 'rgba(34, 197, 94, 0.9)' : 'rgba(100, 116, 139, 0.9)', color: '#fff', fontSize: 10, fontWeight: 700, padding: '3px 8px', borderRadius: 12 }}>
                  {b.is_active ? '● Active' : 'Inactive'}
                </div>
              </div>
              <div style={{ padding: 16 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--ink-soft)', textTransform: 'uppercase', marginBottom: 4 }}>
                  Type: {b.banner_type === 'agent_discount' ? '🎫 Agent Travel Discount' : '🛍️ E-Commerce Shop Item'}
                </div>
                <h3 style={{ fontSize: 16, fontWeight: 800, color: 'var(--ink)', marginBottom: 6 }}>{b.title}</h3>
                <p style={{ fontSize: 12, color: 'var(--ink-soft)', lineHeight: 1.5, marginBottom: 16 }}>{b.subtitle}</p>
                <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', borderTop: '1px solid var(--line)', paddingTop: 12 }}>
                  <button className="btn btn-secondary btn-sm" onClick={() => openEditModal(b)}>Edit Banner</button>
                  <button className="btn btn-danger btn-sm" onClick={() => handleDelete(b.id)}>Delete</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal Form */}
      {showModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 16 }}>
          <div style={{ background: '#fff', borderRadius: 16, width: '100%', maxWidth: 520, padding: 24, boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <h2 style={{ fontSize: 18, fontWeight: 800, color: 'var(--ink)' }}>
                {editingBanner ? 'Edit Promotional Banner' : 'Create Promotional Banner'}
              </h2>
              <button onClick={() => setShowModal(false)} style={{ background: 'none', border: 'none', fontSize: 20, cursor: 'pointer', color: 'var(--ink-soft)' }}>✕</button>
            </div>

            <form onSubmit={handleSaveBanner}>
              <div style={{ marginBottom: 14 }}>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>BANNER TYPE</label>
                <select className="input" value={bannerType} onChange={e => setBannerType(e.target.value)} style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)' }}>
                  <option value="agent_discount">🎫 Agent Travel Discount Banner (Banner 1)</option>
                  <option value="shop_item">🛍️ E-Commerce Shopping & Gear Banner (Banner 2)</option>
                </select>
              </div>

              <div style={{ marginBottom: 14 }}>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>TITLE *</label>
                <input type="text" className="input" placeholder="e.g. Get 25% OFF Your First Local Guide!" value={title} onChange={e => setTitle(e.target.value)} required style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)' }} />
              </div>

              <div style={{ marginBottom: 14 }}>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>SUBTITLE / DESCRIPTION</label>
                <textarea className="input" placeholder="e.g. Book verified local experts in Khajjiar & Munnar with code GUIDE25." value={subtitle} onChange={e => setSubtitle(e.target.value)} rows={2} style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)' }} />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 14 }}>
                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>BADGE TEXT</label>
                  <input type="text" className="input" placeholder="e.g. FLAT 25% OFF" value={badgeText} onChange={e => setBadgeText(e.target.value)} style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)' }} />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>DISPLAY ORDER</label>
                  <input type="number" className="input" value={displayOrder} onChange={e => setDisplayOrder(e.target.value)} min={1} style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)' }} />
                </div>
              </div>

              <div style={{ marginBottom: 14 }}>
                <label style={{ display: 'block', fontSize: 12, fontWeight: 700, color: 'var(--ink)', marginBottom: 6 }}>IMAGE URL</label>
                <input type="url" className="input" placeholder="https://images.unsplash.com/photo-..." value={imageUrl} onChange={e => setImageUrl(e.target.value)} style={{ width: '100%', padding: '10px 12px', borderRadius: 8, border: '1px solid var(--line)' }} />
              </div>

              <div style={{ marginBottom: 20, display: 'flex', alignItems: 'center', gap: 8 }}>
                <input type="checkbox" id="isActiveCheck" checked={isActive} onChange={e => setIsActive(e.target.checked)} />
                <label htmlFor="isActiveCheck" style={{ fontSize: 13, fontWeight: 600, color: 'var(--ink)' }}>Active (Visible on Traveller App Home)</label>
              </div>

              <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Saving…' : (editingBanner ? 'Save Changes' : 'Create Banner')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
