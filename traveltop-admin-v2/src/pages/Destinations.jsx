import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import ConfirmDialog from '../components/ConfirmDialog';
import StatusBadge from '../components/StatusBadge';
import ImageDropzone, { MultiImageDropzone } from '../components/ImageDropzone';

const PAGE_SIZE = 20;
const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const PLACE_CATEGORIES = ['Nature','Beach','Temple','Museum','Market','Adventure','Waterfall','Heritage','Wildlife','Restaurant','Viewpoint','Other'];
const DEST_CATEGORIES = ['Beach','Hills','Honeymoon','Adventure','Solo','Weekend Getaway','Luxury','Wildlife/Nature','Heritage','Backpacking','Religious','Other'];

// ── Place Form (inline) ──────────────────────────────────────────────
function PlaceForm({ place, onSave, onCancel }) {
  const [name, setName] = useState(place?.name || '');
  const [category, setCategory] = useState(place?.category || '');
  const [customCat, setCustomCat] = useState('');
  const [desc, setDesc] = useState(place?.description || '');
  const [duration, setDuration] = useState(place?.ideal_duration || '');
  const [bestTime, setBestTime] = useState(place?.best_time_of_day || '');
  const [images, setImages] = useState(place?.images || []);
  const [saving, setSaving] = useState(false);
  const { toast } = useToast();

  const finalCategory = category === 'Other' ? customCat : category;

  async function save() {
    if (!name.trim()) { toast('Place name is required', 'error'); return; }
    setSaving(true);
    onSave({ name, category: finalCategory, description: desc, ideal_duration: duration, best_time_of_day: bestTime, images });
    setSaving(false);
  }

  return (
    <div style={{ background: 'var(--paper)', border: '1px solid var(--line)', borderRadius: 10, padding: 16, marginTop: 10 }}>
      <div className="field-row">
        <div className="field-group">
          <label className="field-label">Place Name *</label>
          <input className="field-input" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Alleppey Backwaters" />
        </div>
        <div className="field-group">
          <label className="field-label">Category</label>
          <select className="field-input" value={category} onChange={e => setCategory(e.target.value)}>
            <option value="">Select…</option>
            {PLACE_CATEGORIES.map(c => <option key={c}>{c}</option>)}
          </select>
          {category === 'Other' && <input className="field-input" style={{ marginTop: 6 }} value={customCat} onChange={e => setCustomCat(e.target.value)} placeholder="Custom category…" />}
        </div>
      </div>
      <div className="field-group">
        <label className="field-label">Description / Story Caption</label>
        <textarea className="field-input" rows={2} value={desc} onChange={e => setDesc(e.target.value)} placeholder="Describe what makes this place special…" />
      </div>
      <div className="field-row">
        <div className="field-group">
          <label className="field-label">Ideal Duration</label>
          <input className="field-input" value={duration} onChange={e => setDuration(e.target.value)} placeholder="e.g. 2–3 hours" />
        </div>
        <div className="field-group">
          <label className="field-label">Best Time of Day</label>
          <input className="field-input" value={bestTime} onChange={e => setBestTime(e.target.value)} placeholder="e.g. Early morning (7-8 AM start)" />
        </div>
      </div>
      <div className="field-group">
        <label className="field-label">Images * (at least 1 required)</label>
        <MultiImageDropzone bucket="place-images" images={images} onChange={setImages} />
      </div>
      <div className="modal-footer" style={{ padding: '12px 0 0', border: 'none' }}>
        <button className="btn btn-ghost btn-sm" onClick={onCancel}>Cancel</button>
        <button className="btn btn-primary btn-sm" onClick={save} disabled={saving}>{saving ? 'Saving…' : place?.id ? 'Save Changes' : 'Add Place'}</button>
      </div>
    </div>
  );
}

// ── Destination Modal ────────────────────────────────────────────────
function DestModal({ dest, onClose, onSaved }) {
  const isEdit = !!dest?.id;
  const { toast } = useToast();

  const [name, setName] = useState(dest?.name || '');
  const [country, setCountry] = useState(dest?.country || 'India');
  const [coverUrl, setCoverUrl] = useState(dest?.cover_image_url || '');
  const [galleryImages, setGalleryImages] = useState([]);
  const [desc, setDesc] = useState(dest?.description || '');
  const [featured, setFeatured] = useState(dest?.is_featured || false);
  const [trending, setTrending] = useState(dest?.is_trending || false);
  const [bestSeason, setBestSeason] = useState(dest?.best_season || '');
  const [tripDuration, setTripDuration] = useState(dest?.ideal_trip_duration || '');
  const [tips, setTips] = useState(dest?.travel_tips || '');
  const [bestMonths, setBestMonths] = useState(dest?.best_months || []);
  const [riskyMonths, setRiskyMonths] = useState(dest?.risky_months || []);
  const [category, setCategory] = useState(dest?.category || '');

  const [places, setPlaces] = useState([]);
  const [showPlaceForm, setShowPlaceForm] = useState(false);
  const [editingPlace, setEditingPlace] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (dest?.id) {
      fetchPlaces();
      fetchGallery();
    } else {
      setPlaces([]);
      setGalleryImages(dest?.cover_image_url ? [dest.cover_image_url] : []);
    }
  }, [dest?.id]);

  async function fetchGallery() {
    if (!dest?.id) return;
    try {
      const { data, error } = await supabase
        .from('destination_images')
        .select('*')
        .eq('destination_id', dest.id)
        .order('display_order', { ascending: true });
      if (!error && data && data.length > 0) {
        setGalleryImages(data.map(i => i.image_url).filter(Boolean));
      } else if (dest.cover_image_url) {
        setGalleryImages([dest.cover_image_url]);
      } else {
        setGalleryImages([]);
      }
    } catch (e) {
      if (dest.cover_image_url) setGalleryImages([dest.cover_image_url]);
    }
  }

  async function fetchPlaces() {
    if (!dest?.id) return;
    try {
      const { data, error } = await supabase
        .from('places')
        .select('*, place_images(*)')
        .eq('destination_id', dest.id)
        .order('display_order', { ascending: true });

      if (error) {
        console.error('fetchPlaces query error:', error);
        // Fallback: try fetching places without place_images join
        const { data: placesOnly } = await supabase
          .from('places')
          .select('*')
          .eq('destination_id', dest.id);
        if (placesOnly) {
          setPlaces(placesOnly.map(p => ({ ...p, images: [] })));
          return;
        }
      }

      if (data) {
        setPlaces(data.map(p => ({
          ...p,
          images: (p.place_images || [])
            .sort((a, b) => (a.display_order ?? a.sort_order ?? 0) - (b.display_order ?? b.sort_order ?? 0))
            .map(i => i.image_url)
            .filter(Boolean)
        })));
      }
    } catch (e) {
      console.error('fetchPlaces exception:', e);
    }
  }

  function toggleMonth(arr, setArr, m) {
    setArr(arr.includes(m) ? arr.filter(x => x !== m) : [...arr, m]);
  }

  async function savePlace(placeData, idx = null) {
    const sanitized = {
      name: placeData.name || 'Unnamed Place',
      category: placeData.category || '',
      description: placeData.description || '',
      ideal_duration: placeData.ideal_duration || '',
      best_time_of_day: placeData.best_time_of_day || '',
      images: placeData.images || []
    };

    if (!isEdit || !dest?.id) {
      // Stage locally for new destination
      if (idx !== null) setPlaces(places.map((p, i) => i === idx ? { ...p, ...sanitized } : p));
      else setPlaces([...places, { ...sanitized, id: `new_${Date.now()}` }]);
      setShowPlaceForm(false); setEditingPlace(null);
      return;
    }

    // Editing existing destination — save directly to Supabase
    try {
      if (idx !== null && places[idx]?.id && !places[idx].id.startsWith('new_')) {
        const { id } = places[idx];
        const { error: updateErr } = await supabase.from('places').update({
          name: sanitized.name,
          category: sanitized.category,
          description: sanitized.description,
          ideal_duration: sanitized.ideal_duration,
          best_time_of_day: sanitized.best_time_of_day
        }).eq('id', id);
        if (updateErr) throw updateErr;

        if (sanitized.images.length) {
          await supabase.from('place_images').delete().eq('place_id', id);
          for (const [i, url] of sanitized.images.entries()) {
            const { error: imgErr } = await supabase.from('place_images').insert({ place_id: id, image_url: url, display_order: i });
            if (imgErr) {
              await supabase.from('place_images').insert({ place_id: id, image_url: url, sort_order: i });
            }
          }
        }
      } else {
        const { data: newPlace, error: insertErr } = await supabase.from('places').insert({
          destination_id: dest.id,
          name: sanitized.name,
          category: sanitized.category,
          description: sanitized.description,
          ideal_duration: sanitized.ideal_duration,
          best_time_of_day: sanitized.best_time_of_day,
          display_order: places.length
        }).select().single();
        if (insertErr) throw insertErr;

        if (newPlace && sanitized.images.length) {
          for (const [i, url] of sanitized.images.entries()) {
            const { error: imgErr } = await supabase.from('place_images').insert({ place_id: newPlace.id, image_url: url, display_order: i });
            if (imgErr) {
              await supabase.from('place_images').insert({ place_id: newPlace.id, image_url: url, sort_order: i });
            }
          }
        }
      }
      await fetchPlaces();
      setShowPlaceForm(false); setEditingPlace(null);
      toast('Place saved ✓', 'success');
    } catch (e) {
      console.error('savePlace error:', e);
      toast(`Failed to save place: ${e.message}`, 'error');
    }
  }

  async function deletePlace(p, i) {
    if (!p.id || p.id.startsWith('new_')) {
      setPlaces(places.filter((_, idx) => idx !== i)); return;
    }
    await supabase.from('place_images').delete().eq('place_id', p.id);
    await supabase.from('places').delete().eq('id', p.id);
    await fetchPlaces();
    toast('Place removed', 'success');
  }

  async function save() {
    if (!name.trim()) { toast('Destination name is required', 'error'); return; }
    setSaving(true);
    try {
      const finalCountry = country.trim() || 'India';
      const primaryCover = galleryImages.length > 0 ? galleryImages[0] : (coverUrl || '');
      const payload = {
        name: name.trim(),
        country: finalCountry,
        category,
        cover_image_url: primaryCover,
        description: desc,
        is_featured: featured,
        is_trending: trending,
        best_season: bestSeason,
        ideal_trip_duration: tripDuration,
        travel_tips: tips,
        best_months: bestMonths,
        risky_months: riskyMonths
      };

      let destId = dest?.id;
      if (isEdit && destId) {
        const { error: updErr } = await supabase.from('destinations').update(payload).eq('id', destId);
        if (updErr) throw updErr;
      } else {
        const { data, error: insErr } = await supabase.from('destinations').insert(payload).select().single();
        if (insErr) throw insErr;
        destId = data?.id;
      }

      // Save destination gallery images
      if (destId) {
        try {
          await supabase.from('destination_images').delete().eq('destination_id', destId);
          if (galleryImages.length > 0) {
            const imgRows = galleryImages.map((url, idx) => ({
              destination_id: destId,
              image_url: url,
              display_order: idx
            }));
            const { error: imgErr } = await supabase.from('destination_images').insert(imgRows);
            if (imgErr) console.warn('Could not insert destination_images:', imgErr.message);
          }
        } catch (imgEx) {
          console.warn('destination_images operation exception:', imgEx);
        }
      }

      // Save staged places
      if (destId) {
        for (const [i, p] of places.entries()) {
          if (!p.id || p.id.startsWith('new_')) {
            const { data: np, error: placeErr } = await supabase.from('places').insert({
              destination_id: destId,
              name: p.name || 'Unnamed Place',
              category: p.category || '',
              description: p.description || '',
              ideal_duration: p.ideal_duration || '',
              best_time_of_day: p.best_time_of_day || '',
              display_order: i
            }).select().single();

            if (placeErr) console.error('Error inserting staged place:', placeErr);

            if (np && p.images?.length) {
              for (const [j, url] of p.images.entries()) {
                const { error: imgErr } = await supabase.from('place_images').insert({ place_id: np.id, image_url: url, display_order: j });
                if (imgErr) {
                  await supabase.from('place_images').insert({ place_id: np.id, image_url: url, sort_order: j });
                }
              }
            }
          }
        }
      }

      setSaving(false);
      toast(isEdit ? 'Destination updated' : 'Destination created', 'success');
      onSaved();
      onClose();
    } catch (e) {
      console.error('save destination error:', e);
      toast(`Failed to save destination: ${e.message}`, 'error');
      setSaving(false);
    }
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal modal-lg">
        <div className="modal-header">
          <div className="modal-title">{isEdit ? 'Edit Destination' : 'Add Destination'}</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body" style={{ maxHeight: 'calc(90vh - 140px)', overflowY: 'auto' }}>
          <div className="field-row">
            <div className="field-group">
              <label className="field-label">Destination Name *</label>
              <input className="field-input" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Munnar" />
            </div>
            <div className="field-group">
              <label className="field-label">State *</label>
              <input className="field-input" value={country} onChange={e => setCountry(e.target.value)} placeholder="e.g. Assam, Uttarakhand" />
            </div>
            <div className="field-group">
              <label className="field-label">Category</label>
              <select className="field-input" value={category} onChange={e => setCategory(e.target.value)}>
                <option value="">Select category…</option>
                {DEST_CATEGORIES.map(c => <option key={c}>{c}</option>)}
              </select>
            </div>
          </div>

          <div className="field-group">
            <label className="field-label">
              Destination Cover & Gallery Images * ({galleryImages.length} uploaded)
            </label>
            <div style={{ fontSize: 12, color: 'var(--ink-soft)', marginBottom: 8, lineHeight: 1.4 }}>
              The <strong>1st image</strong> automatically serves as the primary card cover everywhere in the app. Use the arrow buttons to reorder, and trash icon to remove images anytime.
            </div>
            <MultiImageDropzone
              bucket="destination-images"
              images={galleryImages}
              onChange={(newImgs) => {
                setGalleryImages(newImgs);
                setCoverUrl(newImgs[0] || '');
              }}
            />
          </div>

          <div className="field-group">
            <label className="field-label">Description</label>
            <textarea className="field-input" rows={3} value={desc} onChange={e => setDesc(e.target.value)} placeholder="Describe the destination…" />
          </div>

          <div className="field-row">
            <div className="field-group">
              <label className="field-label">Best Season</label>
              <input className="field-input" value={bestSeason} onChange={e => setBestSeason(e.target.value)} placeholder="e.g. Oct – Mar (Winter)" />
            </div>
            <div className="field-group">
              <label className="field-label">Ideal Trip Duration</label>
              <input className="field-input" value={tripDuration} onChange={e => setTripDuration(e.target.value)} placeholder="e.g. 3–5 days" />
            </div>
          </div>

          <div className="field-group">
            <label className="field-label">Travel Tips</label>
            <textarea className="field-input" rows={3} value={tips} onChange={e => setTips(e.target.value)} placeholder="Pro tips for travellers…" />
          </div>

          {/* Toggles */}
          <div style={{ display: 'flex', gap: 24, marginBottom: 16 }}>
            <label className="toggle-wrap" style={{ cursor: 'pointer' }}>
              <span className="toggle">
                <input type="checkbox" checked={featured} onChange={e => setFeatured(e.target.checked)} />
                <span className="toggle-slider" />
              </span>
              <span style={{ fontSize: 13, fontWeight: 600 }}>Featured</span>
            </label>
            <label className="toggle-wrap" style={{ cursor: 'pointer' }}>
              <span className="toggle">
                <input type="checkbox" checked={trending} onChange={e => setTrending(e.target.checked)} />
                <span className="toggle-slider" />
              </span>
              <span style={{ fontSize: 13, fontWeight: 600 }}>Trending</span>
            </label>
          </div>

          {/* Best Months */}
          <div className="field-group">
            <label className="field-label">Best Months to Visit</label>
            <div className="months-grid">
              {MONTHS.map(m => (
                <div key={m} className={`month-check${bestMonths.includes(m) ? ' checked' : ''}`} onClick={() => toggleMonth(bestMonths, setBestMonths, m)}>
                  {m}
                </div>
              ))}
            </div>
          </div>

          {/* Risky Months */}
          <div className="field-group">
            <label className="field-label">Risky / Avoid Months</label>
            <div className="months-grid">
              {MONTHS.map(m => (
                <div key={m} className={`month-check${riskyMonths.includes(m) ? ' checked' : ''}`}
                  style={riskyMonths.includes(m) ? { background: 'var(--red-light)', borderColor: 'var(--red)', color: 'var(--red)' } : {}}
                  onClick={() => toggleMonth(riskyMonths, setRiskyMonths, m)}>
                  {m}
                </div>
              ))}
            </div>
          </div>

          {/* Places Section */}
          <hr className="divider" />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <div className="section-title" style={{ marginBottom: 0 }}>Places to Visit</div>
            <button className="btn btn-ghost btn-sm" onClick={() => { setShowPlaceForm(true); setEditingPlace(null); }}>+ Add Place</button>
          </div>

          {places.map((p, i) => (
            <div key={p.id || i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', border: '1px solid var(--line)', borderRadius: 8, marginBottom: 6 }}>
              {p.images?.[0] && <img src={p.images[0]} alt="" style={{ width: 52, height: 40, objectFit: 'cover', borderRadius: 6 }} />}
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: 13 }}>{p.name}</div>
                <div className="cell-muted">{p.category}</div>
              </div>
              <div className="action-row">
                <button className="btn btn-ghost btn-xs" onClick={() => { setEditingPlace({ ...p, idx: i }); setShowPlaceForm(true); }}>Edit</button>
                <button className="btn btn-danger-text btn-xs" onClick={() => deletePlace(p, i)}>Remove</button>
              </div>
            </div>
          ))}

          {/* Edit / Add Place → nested overlay modal */}
          {showPlaceForm && (
            <div
              style={{
                position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                zIndex: 2000, padding: 16,
              }}
              onClick={e => { if (e.target === e.currentTarget) { setShowPlaceForm(false); setEditingPlace(null); } }}
            >
              <div style={{ background: '#fff', borderRadius: 14, width: '100%', maxWidth: 500, boxShadow: '0 20px 40px rgba(0,0,0,0.18)', overflow: 'hidden' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid var(--line)' }}>
                  <div style={{ fontWeight: 800, fontSize: 16, color: 'var(--ink)' }}>
                    {editingPlace?.id ? '✏️ Edit Place' : '➕ Add New Place'}
                  </div>
                  <button onClick={() => { setShowPlaceForm(false); setEditingPlace(null); }} style={{ background: 'none', border: 'none', fontSize: 18, cursor: 'pointer', color: 'var(--ink-soft)' }}>✕</button>
                </div>
                <div style={{ padding: '16px 20px', maxHeight: '70vh', overflowY: 'auto' }}>
                  <PlaceForm
                    key={editingPlace?.id || 'new-place'}
                    place={editingPlace}
                    onSave={data => savePlace(data, editingPlace?.idx ?? null)}
                    onCancel={() => { setShowPlaceForm(false); setEditingPlace(null); }}
                  />
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? 'Saving…' : isEdit ? 'Save Changes' : 'Create Destination'}</button>
        </div>
      </div>
    </div>
  );
}

// ── Main Page ────────────────────────────────────────────────────────
export default function Destinations() {
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
      let q = supabase.from('destinations')
        .select(`*, places(count), destination_images(count)`, { count: 'exact' });
      if (search) q = q.ilike('name', `%${search}%`);
      q = q.order('created_at', { ascending: false })
           .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

      const { data, count, error: err } = await q;
      if (err) {
        // Fallback without destination_images join if schema not yet refreshed
        let qFallback = supabase.from('destinations').select(`*, places(count)`, { count: 'exact' });
        if (search) qFallback = qFallback.ilike('name', `%${search}%`);
        qFallback = qFallback.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
        const { data: d2, count: c2, error: err2 } = await qFallback;
        if (err2) throw err2;
        setRows(d2 || []);
        setTotal(c2 || 0);
        setError(null);
        return;
      }
      setRows(data || []);
      setTotal(count || 0);
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => { fetchData(); }, [fetchData]);

  // Real-time
  useEffect(() => {
    const ch = supabase.channel('destinations_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'destinations' }, fetchData)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'destination_images' }, fetchData)
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, [fetchData]);

  async function toggleField(id, field, val) {
    await supabase.from('destinations').update({ [field]: val }).eq('id', id);
    setRows(rows.map(r => r.id === id ? { ...r, [field]: val } : r));
  }

  async function confirmDelete() {
    const id = deleteTarget.id;
    await supabase.from('destination_images').delete().eq('destination_id', id);
    await supabase.from('place_images').delete().in('place_id', supabase.from('places').select('id').eq('destination_id', id));
    await supabase.from('places').delete().eq('destination_id', id);
    await supabase.from('destinations').delete().eq('id', id);
    setDeleteTarget(null);
    toast('Destination deleted', 'success');
    fetchData();
  }

  const isIncomplete = d => !d.best_months?.length || !d.travel_tips;

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input
              className="search-input"
              placeholder="Search destinations…"
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
          <div style={{ flex: 1 }} />
          <button className="btn btn-primary btn-sm" onClick={() => setModal({})}>+ Add Destination</button>
        </div>

        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>Destination</th>
              <th>State</th>
              <th>Rating</th>
              <th>Photos</th>
              <th>Featured</th>
              <th>Trending</th>
              <th>Places</th>
              <th>Status</th>
              <th>Actions</th>
            </tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={9}><Skeleton rows={8} cols={9} /></td></tr>
                : error ? <tr><td colSpan={9}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={9}>
                    <div className="empty-state">
                      <div className="empty-state-icon">📍</div>
                      <div className="empty-state-title">No destinations yet</div>
                      <div className="empty-state-desc">Add your first destination to get started.</div>
                    </div>
                  </td></tr>
                ) : rows.map(d => (
                  <tr key={d.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        {d.cover_image_url
                          ? <img src={d.cover_image_url} className="cell-img" alt="" onError={e => e.target.style.display='none'} />
                          : <div style={{ width: 48, height: 36, background: 'var(--paper)', borderRadius: 6, border: '1px solid var(--line)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18 }}>📍</div>
                        }
                        <div>
                          <div style={{ fontWeight: 600 }}>{d.name}</div>
                          {isIncomplete(d) && <span className="incomplete-badge">Incomplete</span>}
                        </div>
                      </div>
                    </td>
                    <td className="cell-muted">{d.country}</td>
                    <td style={{ minWidth: 100 }}>
                      {Number(d.rating_avg || 0) > 0 ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                          <span style={{ color: '#f59e0b', fontSize: 13 }}>★</span>
                          <span style={{ fontWeight: 700, fontSize: 12.5 }}>{Number(d.rating_avg).toFixed(1)}</span>
                          <span style={{ fontSize: 11, color: 'var(--ink-soft)' }}>({d.review_count || 0})</span>
                        </div>
                      ) : (
                        <span style={{ fontSize: 11, color: 'var(--ink-soft)' }}>No reviews</span>
                      )}
                    </td>
                    <td>
                      <span className="badge badge-gray" style={{ fontWeight: 600 }}>
                        {d.destination_images?.[0]?.count ?? (d.cover_image_url ? 1 : 0)} photos
                      </span>
                    </td>
                    <td>
                      <label className="toggle">
                        <input type="checkbox" checked={d.is_featured} onChange={e => toggleField(d.id, 'is_featured', e.target.checked)} />
                        <span className="toggle-slider" />
                      </label>
                    </td>
                    <td>
                      <label className="toggle">
                        <input type="checkbox" checked={d.is_trending} onChange={e => toggleField(d.id, 'is_trending', e.target.checked)} />
                        <span className="toggle-slider" />
                      </label>
                    </td>
                    <td><span className="badge badge-gray">{d.places?.[0]?.count ?? 0}</span></td>
                    <td><StatusBadge status={d.is_featured ? 'active' : 'inactive'} /></td>
                    <td>
                      <div className="action-row">
                        <button className="btn btn-ghost btn-xs" onClick={() => setModal(d)}>Edit</button>
                        <button className="btn btn-danger-text btn-xs" onClick={() => setDeleteTarget(d)}>Delete</button>
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

      {modal !== null && <DestModal dest={modal?.id ? modal : null} onClose={() => setModal(null)} onSaved={fetchData} />}

      {deleteTarget && (
        <ConfirmDialog
          title="Delete Destination?"
          description={`"${deleteTarget.name}" and all its places will be permanently removed.`}
          confirmLabel="Delete"
          confirmClass="btn btn-primary"
          onConfirm={confirmDelete}
          onCancel={() => setDeleteTarget(null)}
        />
      )}
    </div>
  );
}
