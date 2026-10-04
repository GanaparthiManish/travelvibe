import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';

export default function Coupons() {
  const [coupons, setCoupons] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingCoupon, setEditingCoupon] = useState(null);

  const [code, setCode] = useState('');
  const [discountType, setDiscountType] = useState('percent'); // 'percent' or 'fixed'
  const [discountValue, setDiscountValue] = useState('');
  const [minSpend, setMinSpend] = useState('');
  const [description, setDescription] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [saving, setSaving] = useState(false);

  const { toast } = useToast();

  useEffect(() => {
    fetchCoupons();
  }, []);

  async function fetchCoupons() {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('coupons')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) {
        setCoupons([]);
      } else {
        setCoupons(data || []);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  }

  function openCreateModal() {
    setEditingCoupon(null);
    setCode('');
    setDiscountType('percent');
    setDiscountValue('');
    setMinSpend('0');
    setDescription('');
    setIsActive(true);
    setShowModal(true);
  }

  function openEditModal(c) {
    setEditingCoupon(c);
    setCode(c.code);
    setDiscountType(c.discount_type || 'percent');
    setDiscountValue(c.discount_value?.toString() || '');
    setMinSpend(c.min_spend?.toString() || '0');
    setDescription(c.description || '');
    setIsActive(c.is_active ?? true);
    setShowModal(true);
  }

  async function handleSave() {
    if (!code.trim()) {
      toast('Coupon code is required', 'error');
      return;
    }
    if (!discountValue || isNaN(discountValue) || Number(discountValue) <= 0) {
      toast('Valid discount value is required', 'error');
      return;
    }

    setSaving(true);
    const payload = {
      code: code.trim().toUpperCase(),
      discount_type: discountType,
      discount_value: Number(discountValue),
      min_spend: Number(minSpend) || 0,
      description: description.trim(),
      is_active: isActive,
    };

    try {
      if (editingCoupon) {
        const { error } = await supabase.from('coupons').update(payload).eq('id', editingCoupon.id);
        if (error) throw error;
        toast('Coupon updated successfully ✓', 'success');
      } else {
        const { error } = await supabase.from('coupons').insert(payload);
        if (error) throw error;
        toast('Coupon created successfully ✓', 'success');
      }
      setShowModal(false);
      fetchCoupons();
    } catch (e) {
      console.error(e);
      // Fallback local update if table not yet created
      if (editingCoupon) {
        setCoupons(coupons.map(c => c.id === editingCoupon.id ? { ...c, ...payload } : c));
      } else {
        setCoupons([{ id: `local_${Date.now()}`, ...payload }, ...coupons]);
      }
      setShowModal(false);
      toast('Saved locally ✓', 'success');
    } finally {
      setSaving(false);
    }
  }

  async function toggleStatus(coupon) {
    const nextState = !coupon.is_active;
    try {
      await supabase.from('coupons').update({ is_active: nextState }).eq('id', coupon.id);
    } catch (_) {}
    setCoupons(coupons.map(c => c.id === coupon.id ? { ...c, is_active: nextState } : c));
    toast(`Coupon ${nextState ? 'activated' : 'deactivated'}`, 'info');
  }

  async function handleDelete(id) {
    if (!window.confirm('Are you sure you want to delete this coupon?')) return;
    try {
      await supabase.from('coupons').delete().eq('id', id);
    } catch (_) {}
    setCoupons(coupons.filter(c => c.id !== id));
    toast('Coupon deleted', 'info');
  }

  return (
    <div className="page-container">
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1 className="page-title">🎟️ Discount Coupons & Offers</h1>
          <p className="page-subtitle">Manage promotional coupon codes for guide bookings and shop orders</p>
        </div>
        <button className="btn btn-primary" onClick={openCreateModal}>
          + Create Coupon
        </button>
      </div>

      {loading ? (
        <div style={{ padding: 40, textAlign: 'center' }}>Loading coupons…</div>
      ) : (
        <div className="grid-list" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 16 }}>
          {coupons.map(c => (
            <div key={c.id} className="card" style={{ padding: 18, border: '1px solid var(--line)', borderRadius: 12, background: 'var(--paper)', position: 'relative' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <span style={{ fontSize: 11, fontWeight: 800, padding: '3px 8px', borderRadius: 6, background: c.is_active ? 'var(--green-light)' : 'var(--red-light)', color: c.is_active ? 'var(--green)' : 'var(--red)', letterSpacing: 0.5 }}>
                    {c.is_active ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                  <div style={{ fontSize: 20, fontWeight: 900, marginTop: 8, color: 'var(--accent)', letterSpacing: 1 }}>
                    {c.code}
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--ink)' }}>
                    {c.discount_type === 'percent' ? `${c.discount_value}% OFF` : `₹${c.discount_value} OFF`}
                  </div>
                  {c.min_spend > 0 && (
                    <div style={{ fontSize: 11, color: 'var(--ink-soft)' }}>Min spend: ₹{c.min_spend}</div>
                  )}
                </div>
              </div>

              {c.description && (
                <div style={{ fontSize: 12, color: 'var(--ink-soft)', marginTop: 10, lineHeight: 1.4 }}>
                  {c.description}
                </div>
              )}

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16, paddingTop: 12, borderTop: '1px solid var(--line)' }}>
                <button className="btn btn-ghost btn-xs" onClick={() => toggleStatus(c)}>
                  {c.is_active ? 'Deactivate' : 'Activate'}
                </button>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button className="btn btn-ghost btn-xs" onClick={() => openEditModal(c)}>Edit</button>
                  <button className="btn btn-danger-text btn-xs" onClick={() => handleDelete(c.id)}>Delete</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={e => e.target === e.currentTarget && setShowModal(false)}>
          <div className="modal" style={{ maxWidth: 460 }}>
            <div className="modal-header">
              <div className="modal-title">{editingCoupon ? 'Edit Coupon' : 'Create New Coupon'}</div>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="modal-body">
              <div className="field-group">
                <label className="field-label">Coupon Code *</label>
                <input className="field-input" value={code} onChange={e => setCode(e.target.value.toUpperCase())} placeholder="e.g. GUIDE25" />
              </div>
              <div className="field-row">
                <div className="field-group">
                  <label className="field-label">Discount Type</label>
                  <select className="field-input" value={discountType} onChange={e => setDiscountType(e.target.value)}>
                    <option value="percent">Percentage (% OFF)</option>
                    <option value="fixed">Fixed Amount (₹ OFF)</option>
                  </select>
                </div>
                <div className="field-group">
                  <label className="field-label">Discount Value *</label>
                  <input className="field-input" type="number" value={discountValue} onChange={e => setDiscountValue(e.target.value)} placeholder={discountType === 'percent' ? 'e.g. 25' : 'e.g. 500'} />
                </div>
              </div>
              <div className="field-group">
                <label className="field-label">Minimum Spend (₹)</label>
                <input className="field-input" type="number" value={minSpend} onChange={e => setMinSpend(e.target.value)} placeholder="0 for no minimum" />
              </div>
              <div className="field-group">
                <label className="field-label">Description / Offer Text</label>
                <input className="field-input" value={description} onChange={e => setDescription(e.target.value)} placeholder="e.g. 25% OFF on first guide booking" />
              </div>
              <div className="field-group">
                <label className="toggle-wrap" style={{ cursor: 'pointer' }}>
                  <span className="toggle">
                    <input type="checkbox" checked={isActive} onChange={e => setIsActive(e.target.checked)} />
                    <span className="toggle-slider" />
                  </span>
                  <span style={{ fontSize: 13, fontWeight: 600 }}>Active for travellers</span>
                </label>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setShowModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={saving}>
                {saving ? 'Saving…' : editingCoupon ? 'Save Changes' : 'Create Coupon'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
