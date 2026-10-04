import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import ConfirmDialog from '../components/ConfirmDialog';
import ImageDropzone from '../components/ImageDropzone';

const PAGE_SIZE = 20;

function ProductModal({ product, onClose, onSaved }) {
  const isEdit = !!product?.id;
  const { toast } = useToast();
  const [name, setName] = useState(product?.name || '');
  const [desc, setDesc] = useState(product?.description || '');
  const [price, setPrice] = useState(product?.price || '');
  const [stock, setStock] = useState(product?.stock ?? '');
  const [imageUrl, setImageUrl] = useState(product?.image_url || '');
  const [saving, setSaving] = useState(false);

  async function save() {
    if (!name.trim()) { toast('Name is required', 'error'); return; }
    setSaving(true);
    const newProd = {
      name,
      description: desc,
      price: Number(price) || 0,
      stock: Number(stock) || 0,
      rating: product?.rating || 5.0,
      category: product?.category || 'Gear',
      image_url: imageUrl || null,
    };
    if (isEdit) newProd.id = product.id;

    // 1. DB operation with explicit error check
    const { data: savedData, error: saveErr } = isEdit
      ? await supabase.from('products').update(newProd).eq('id', product.id).select().single()
      : await supabase.from('products').insert(newProd).select().single();

    if (saveErr) {
      toast('Failed to save product: ' + saveErr.message, 'error');
      setSaving(false);
      return;
    }

    const finalProd = savedData || newProd;

    // 2. Broadcast via Supabase Realtime Channel
    try {
      const channel = supabase.channel('product_updates_channel');
      await channel.send({
        type: 'broadcast',
        event: isEdit ? 'product_updated' : 'product_added',
        payload: finalProd,
      });
    } catch (_) {}

    setSaving(false);
    toast(isEdit ? 'Product updated & synced live ✓' : 'Product created & broadcasted live ✓', 'success');
    onSaved(finalProd);
    onClose();
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <div className="modal-header">
          <div className="modal-title">{isEdit ? 'Edit Product' : 'Add Product'}</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          <div className="field-group">
            <label className="field-label">Product Name *</label>
            <input className="field-input" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Travel Backpack" />
          </div>
          <div className="field-group">
            <label className="field-label">Description</label>
            <textarea className="field-input" rows={2} value={desc} onChange={e => setDesc(e.target.value)} />
          </div>
          <div className="field-row">
            <div className="field-group">
              <label className="field-label">Price (₹)</label>
              <input className="field-input" type="number" value={price} onChange={e => setPrice(e.target.value)} placeholder="999" />
            </div>
            <div className="field-group">
              <label className="field-label">Stock</label>
              <input className="field-input" type="number" value={stock} onChange={e => setStock(e.target.value)} placeholder="50" />
            </div>
          </div>
          <ImageDropzone bucket="product-images" value={imageUrl} onChange={setImageUrl} label="Product Image" />
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? 'Saving…' : isEdit ? 'Save Changes' : 'Add Product'}</button>
        </div>
      </div>
    </div>
  );
}

export default function Products() {
  const { toast } = useToast();
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [modal, setModal] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      let q = supabase.from('products').select('*', { count: 'exact' });
      if (search) q = q.ilike('name', `%${search}%`);
      q = q.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
      const { data, count, error: err } = await q;
      if (err) throw err;

      const dbProds = data || [];
      setRows(dbProds);
      setTotal(count || 0);
      setError(null);
    } catch (e) {
      setRows([]);
      setTotal(0);
      setError(e.message || 'Error loading products');
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => {
    fetchData();

    // Realtime channel listener for products
    const channel = supabase.channel('products_rt_channel')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'products' }, fetchData)
      .subscribe();

    return () => supabase.removeChannel(channel);
  }, [fetchData]);

  const handleSavedProduct = (savedProd) => {
    fetchData();
  };

  async function deleteProduct() {
    try {
      const { error: delErr } = await supabase.from('products').delete().eq('id', deleteTarget.id);
      if (delErr) {
        toast('Delete failed: ' + delErr.message, 'error');
        setDeleteTarget(null);
        return;
      }
    } catch (_) {}

    try {
      const channel = supabase.channel('product_updates_channel');
      await channel.send({
        type: 'broadcast',
        event: 'product_deleted',
        payload: { id: deleteTarget.id },
      });
    } catch (_) {}

    fetchData();
    toast('Product deleted ✓', 'success');
    setDeleteTarget(null);
  }

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search products…" value={search} onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
          <div style={{ flex: 1 }} />
          <button className="btn btn-primary btn-sm" onClick={() => setModal({})}>+ Add Product</button>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Product</th><th>Price</th><th>Stock</th><th>Rating</th><th>Actions</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={5}><Skeleton rows={6} cols={5} /></td></tr>
                : error ? <tr><td colSpan={5}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={5}><div className="empty-state"><div className="empty-state-icon">🛍️</div><div className="empty-state-title">No products yet</div></div></td></tr>
                ) : rows.map(p => (
                  <tr key={p.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        {p.image_url
                          ? <img src={p.image_url} className="cell-img" alt="" onError={e => { e.target.style.display = 'none'; if (e.target.nextSibling) e.target.nextSibling.style.display = 'flex'; }} />
                          : null
                        }
                        <div className="cell-img-fallback" style={{ width: 48, height: 36, background: 'var(--paper)', borderRadius: 6, border: '1px solid var(--line)', display: p.image_url ? 'none' : 'flex', alignItems: 'center', justifyContent: 'center' }}>🛍️</div>
                        <div>
                          <div style={{ fontWeight: 600 }}>{p.name}</div>
                          <div className="cell-muted" style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{p.description}</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ fontWeight: 600 }}>₹{(p.price || 0).toLocaleString('en-IN')}</td>
                    <td><span className={`badge ${p.stock > 10 ? 'badge-green' : p.stock > 0 ? 'badge-amber' : 'badge-red'}`}>{p.stock ?? '—'}</span></td>
                    <td>{p.rating ? `⭐ ${p.rating}` : '—'}</td>
                    <td>
                      <div className="action-row">
                        <button className="btn btn-ghost btn-xs" onClick={() => setModal(p)}>Edit</button>
                        <button className="btn btn-danger-text btn-xs" onClick={() => setDeleteTarget(p)}>Delete</button>
                      </div>
                    </td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
      </div>

      {modal !== null && <ProductModal product={modal?.id ? modal : null} onClose={() => setModal(null)} onSaved={handleSavedProduct} />}
      {deleteTarget && (
        <ConfirmDialog title="Delete Product?" description={`"${deleteTarget.name}" will be permanently removed.`}
          confirmLabel="Delete" confirmClass="btn btn-primary" onConfirm={deleteProduct} onCancel={() => setDeleteTarget(null)} />
      )}
    </div>
  );
}
