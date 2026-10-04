import React, { useState, useEffect, useCallback } from 'react';
import './App.css';
import * as api from './api';

const COLORS = [
  '#6B8F71','#4A7FA5','#D4A853','#5C8A4E',
  '#8B6BAE','#D47B6B','#4A8FA5','#A5784A',
];

const QUICK_PHOTOS = [
  'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1501854140801-50d01698950b?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1516690561799-46d8f74f9abf?auto=format&fit=crop&w=800&q=80',
  'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=800&q=80',
];

const THUMB_PHOTOS = QUICK_PHOTOS.map(u => u.replace('w=800', 'w=120'));

// ── Toast ────────────────────────────────────────────────────────
function Toast({ msg, onDone }) {
  useEffect(() => {
    const t = setTimeout(onDone, 3000);
    return () => clearTimeout(t);
  }, [onDone]);
  return <div className="toast">{msg}</div>;
}

// ── Color Swatches ───────────────────────────────────────────────
function ColorPicker({ value, onChange }) {
  return (
    <div className="color-row">
      {COLORS.map(c => (
        <div
          key={c}
          className={`swatch${value === c ? ' selected' : ''}`}
          style={{ background: c }}
          onClick={() => onChange(c)}
        />
      ))}
    </div>
  );
}

// ── Splash Section ───────────────────────────────────────────────
function SplashSection({ data, onSave }) {
  const [imageUrl, setImageUrl] = useState(data?.imageUrl || '');
  const [tagline, setTagline] = useState(data?.tagline || '');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setImageUrl(data?.imageUrl || '');
    setTagline(data?.tagline || '');
  }, [data]);

  async function save() {
    setSaving(true);
    await api.patchSplash({ imageUrl, tagline });
    setSaving(false);
    onSave('✅ Splash updated — app refreshes in 5s');
  }

  return (
    <div className="card">
      <div className="card-header">
        <div>
          <div className="card-title">Hero Image</div>
          <div className="card-meta">Shown on the app splash screen</div>
        </div>
        <button className="btn btn-primary btn-sm" onClick={save} disabled={saving}>
          {saving ? 'Saving…' : 'Save Changes'}
        </button>
      </div>

      {imageUrl && (
        <img className="splash-preview" src={imageUrl} alt="Splash preview"
          onError={e => e.target.style.display = 'none'} />
      )}

      <div className="field-group">
        <label className="field-label">Image URL (Unsplash or any URL)</label>
        <input
          className="field-input"
          value={imageUrl}
          onChange={e => setImageUrl(e.target.value)}
          placeholder="https://images.unsplash.com/..."
        />
      </div>

      <div className="field-group">
        <label className="field-label">Tagline</label>
        <input
          className="field-input"
          value={tagline}
          onChange={e => setTagline(e.target.value)}
          placeholder="Local guides, real experiences"
        />
      </div>

      <p style={{ fontSize: 11, color: '#6B6B6B', marginBottom: 8 }}>
        Quick nature photos (click to use):
      </p>
      <div className="quick-photos">
        {QUICK_PHOTOS.map((url, i) => (
          <img
            key={i}
            className={`quick-photo${imageUrl === url ? ' selected' : ''}`}
            src={THUMB_PHOTOS[i]}
            alt=""
            onClick={() => setImageUrl(url)}
          />
        ))}
      </div>
    </div>
  );
}

// ── Destination Modal ────────────────────────────────────────────
function DestModal({ item, onClose, onSaved }) {
  const isEdit = !!item?.id;
  const [name, setName] = useState(item?.name || '');
  const [location, setLocation] = useState(item?.location || '');
  const [agentCount, setAgentCount] = useState(item?.agentCount ?? '');
  const [category, setCategory] = useState(item?.category || 'all');
  const [imageUrl, setImageUrl] = useState(item?.imageUrl || '');
  const [color, setColor] = useState(item?.color || COLORS[0]);
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    const payload = { name, location, agentCount: Number(agentCount), category, imageUrl, color };
    if (isEdit) await api.putDestination(item.id, payload);
    else await api.postDestination(payload);
    setSaving(false);
    onSaved('✅ Destination saved — app updates in 5s');
    onClose();
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <h3>{isEdit ? 'Edit Destination' : 'Add Destination'}</h3>
        <div className="field-group">
          <label className="field-label">Name</label>
          <input className="field-input" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Munnar" />
        </div>
        <div className="field-group">
          <label className="field-label">Location / State</label>
          <input className="field-input" value={location} onChange={e => setLocation(e.target.value)} placeholder="e.g. Kerala" />
        </div>
        <div className="field-group">
          <label className="field-label">Agent Count</label>
          <input className="field-input" type="number" value={agentCount} onChange={e => setAgentCount(e.target.value)} placeholder="12" />
        </div>
        <div className="field-group">
          <label className="field-label">Category</label>
          <select className="field-input" value={category} onChange={e => setCategory(e.target.value)}>
            <option value="all">All</option>
            <option value="beach">Beach</option>
            <option value="hills">Hills</option>
            <option value="honeymoon">Honeymoon</option>
          </select>
        </div>
        <div className="field-group">
          <label className="field-label">Image URL</label>
          <input className="field-input" value={imageUrl} onChange={e => setImageUrl(e.target.value)} placeholder="https://images.unsplash.com/..." />
        </div>
        <div className="field-group">
          <label className="field-label">Card Color</label>
          <ColorPicker value={color} onChange={setColor} />
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
        </div>
      </div>
    </div>
  );
}

// ── Agent Modal ──────────────────────────────────────────────────
function AgentModal({ item, onClose, onSaved }) {
  const isEdit = !!item?.id;
  const [name, setName] = useState(item?.name || '');
  const [specialty, setSpecialty] = useState(item?.specialty || '');
  const [location, setLocation] = useState(item?.location || '');
  const [rating, setRating] = useState(item?.rating ?? '');
  const [pricePerDay, setPrice] = useState(item?.pricePerDay ?? '');
  const [color, setColor] = useState(item?.color || COLORS[0]);
  const [saving, setSaving] = useState(false);

  async function save() {
    setSaving(true);
    const payload = { name, specialty, location, rating: Number(rating), pricePerDay: Number(pricePerDay), color };
    if (isEdit) await api.putAgent(item.id, payload);
    else await api.postAgent(payload);
    setSaving(false);
    onSaved('✅ Agent saved — app updates in 5s');
    onClose();
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal">
        <h3>{isEdit ? 'Edit Agent' : 'Add Agent'}</h3>
        <div className="field-group">
          <label className="field-label">Name</label>
          <input className="field-input" value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Priya Sharma" />
        </div>
        <div className="field-group">
          <label className="field-label">Specialty</label>
          <input className="field-input" value={specialty} onChange={e => setSpecialty(e.target.value)} placeholder="e.g. Family friendly" />
        </div>
        <div className="field-group">
          <label className="field-label">Location</label>
          <input className="field-input" value={location} onChange={e => setLocation(e.target.value)} placeholder="e.g. Munnar" />
        </div>
        <div className="field-group">
          <label className="field-label">Rating (out of 5)</label>
          <input className="field-input" type="number" step="0.1" min="1" max="5" value={rating} onChange={e => setRating(e.target.value)} placeholder="4.9" />
        </div>
        <div className="field-group">
          <label className="field-label">Price per Day (₹)</label>
          <input className="field-input" type="number" value={pricePerDay} onChange={e => setPrice(e.target.value)} placeholder="2500" />
        </div>
        <div className="field-group">
          <label className="field-label">Avatar Color</label>
          <ColorPicker value={color} onChange={setColor} />
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? 'Saving…' : 'Save'}</button>
        </div>
      </div>
    </div>
  );
}

// ── Main App ─────────────────────────────────────────────────────
const TABS = [
  { id: 'splash', icon: '🖼️', label: 'Splash Screen' },
  { id: 'destinations', icon: '📍', label: 'Destinations' },
  { id: 'agents', icon: '👤', label: 'Agents' },
  { id: 'categories', icon: '🏷️', label: 'Categories' },
];

export default function App() {
  const [tab, setTab] = useState('splash');
  const [appData, setAppData] = useState(null);
  const [serverOk, setServerOk] = useState(true);
  const [toast, setToast] = useState(null);

  // Modals
  const [destModal, setDestModal] = useState(null); // null | {} | item
  const [agentModal, setAgentModal] = useState(null);

  // Category local edits
  const [cats, setCats] = useState([]);
  const [savingCats, setSavingCats] = useState(false);

  const showToast = useCallback((msg) => {
    setToast(msg);
  }, []);

  const refresh = useCallback(async () => {
    try {
      const data = await api.fetchData();
      setAppData(data);
      setCats(data.categories || []);
      setServerOk(true);
    } catch {
      setServerOk(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 5000);
    return () => clearInterval(interval);
  }, [refresh]);

  async function deleteDest(id) {
    if (!window.confirm('Delete this destination?')) return;
    await api.deleteDestination(id);
    await refresh();
    showToast('🗑️ Destination deleted');
  }

  async function deleteAgentItem(id) {
    if (!window.confirm('Delete this agent?')) return;
    await api.deleteAgent(id);
    await refresh();
    showToast('🗑️ Agent deleted');
  }

  function addCat() {
    setCats([...cats, { id: 'c' + Date.now(), emoji: '🌟', label: 'New' }]);
  }
  function removeCat(i) {
    setCats(cats.filter((_, idx) => idx !== i));
  }
  function updateCat(i, field, val) {
    setCats(cats.map((c, idx) => idx === i ? { ...c, [field]: val } : c));
  }
  async function saveCats() {
    setSavingCats(true);
    await api.putCategories(cats);
    await refresh();
    setSavingCats(false);
    showToast('✅ Categories saved — app updates in 5s');
  }

  const topTitle = TABS.find(t => t.id === tab)?.label || '';

  return (
    <div className="layout">
      {/* ── Sidebar ── */}
      <aside className="sidebar">
        <div className="sidebar-brand">
          <div className="brand-logo">
            <div className="diamond-box">
              <svg width="16" height="16" viewBox="0 0 16 16" fill="#E8483A">
                <polygon points="8,0 12,7.5 8,16 4,7.5"/>
              </svg>
            </div>
            <div>
              <div className="brand-name">TravelTop</div>
              <div className="brand-sub">Admin Dashboard</div>
            </div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {TABS.map(t => (
            <button
              key={t.id}
              className={`nav-item${tab === t.id ? ' active' : ''}`}
              onClick={() => setTab(t.id)}
            >
              <span className="nav-icon">{t.icon}</span>
              {t.label}
            </button>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="status-dot" style={{ background: serverOk ? '#10B981' : '#EF4444' }} />
          <span className="status-text">{serverOk ? 'Live sync active' : 'Server offline'}</span>
        </div>
      </aside>

      {/* ── Main ── */}
      <div className="main">
        <div className="topbar">
          <h2>{topTitle}</h2>
          <div className="topbar-right">
            <div className="live-badge">
              <div className="status-dot" style={{ width: 6, height: 6, margin: 0, background: serverOk ? '#10B981' : '#EF4444' }} />
              {serverOk ? 'Real-time' : 'Offline'}
            </div>
            <button className="btn btn-ghost btn-sm" onClick={() => window.open('http://localhost:9090', '_blank')}>
              Preview App →
            </button>
          </div>
        </div>

        <div className="content">
          {!serverOk && (
            <div className="server-warning">
              ⚠️ Cannot reach admin server at port 3001. Make sure it's running: <code>node server.js</code>
            </div>
          )}

          {/* Stats */}
          {appData && (
            <div className="stats-row">
              <div className="stat-card"><div className="stat-icon">📍</div><div className="stat-num">{appData.destinations?.length || 0}</div><div className="stat-label">Destinations</div></div>
              <div className="stat-card"><div className="stat-icon">👤</div><div className="stat-num">{appData.agents?.length || 0}</div><div className="stat-label">Agents</div></div>
              <div className="stat-card"><div className="stat-icon">🏷️</div><div className="stat-num">{appData.categories?.length || 0}</div><div className="stat-label">Categories</div></div>
              <div className="stat-card"><div className="stat-icon">🔄</div><div className="stat-num">{serverOk ? '5s' : '—'}</div><div className="stat-label">Sync Interval</div></div>
            </div>
          )}

          {/* ── Splash ── */}
          {tab === 'splash' && appData && (
            <SplashSection data={appData.splash} onSave={showToast} />
          )}

          {/* ── Destinations ── */}
          {tab === 'destinations' && appData && (
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Destinations</div>
                  <div className="card-meta">Shown on Home → Featured</div>
                </div>
                <button className="btn btn-primary btn-sm" onClick={() => setDestModal({})}>
                  + Add Destination
                </button>
              </div>
              <div className="dest-grid">
                {appData.destinations.map(d => (
                  <div className="dest-card" key={d.id}>
                    {d.imageUrl
                      ? <img className="dest-card-img" src={d.imageUrl} alt={d.name}
                          onError={e => { e.target.style.display='none'; }}/>
                      : <div className="dest-card-color" style={{ background: d.color }} />
                    }
                    <div className="dest-card-body">
                      <div className="dest-card-name">{d.name}</div>
                      <div className="dest-card-meta">{d.location} · {d.agentCount} agents · {d.category}</div>
                    </div>
                    <div className="dest-card-actions">
                      <button className="btn btn-ghost btn-sm" onClick={() => setDestModal(d)}>Edit</button>
                      <button className="btn btn-danger" onClick={() => deleteDest(d.id)}>Delete</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── Agents ── */}
          {tab === 'agents' && appData && (
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Agents</div>
                  <div className="card-meta">Shown on Home → Top rated agents</div>
                </div>
                <button className="btn btn-primary btn-sm" onClick={() => setAgentModal({})}>
                  + Add Agent
                </button>
              </div>
              {appData.agents.map(a => (
                <div className="agent-row" key={a.id}>
                  <div className="agent-avatar" style={{ background: a.color }} />
                  <div className="agent-info">
                    <div className="agent-name">{a.name}</div>
                    <div className="agent-meta">{a.location} · {a.specialty} · ★{a.rating} · ₹{a.pricePerDay.toLocaleString()}/day</div>
                  </div>
                  <div className="agent-actions">
                    <button className="btn btn-ghost btn-sm" onClick={() => setAgentModal(a)}>Edit</button>
                    <button className="btn btn-danger" onClick={() => deleteAgentItem(a.id)}>Delete</button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* ── Categories ── */}
          {tab === 'categories' && (
            <div className="card">
              <div className="card-header">
                <div>
                  <div className="card-title">Categories</div>
                  <div className="card-meta">Shown on Home screen filter row</div>
                </div>
                <button className="btn btn-primary btn-sm" onClick={addCat}>+ Add</button>
              </div>
              {cats.map((c, i) => (
                <div className="cat-row" key={c.id}>
                  <div className="cat-emoji">{c.emoji}</div>
                  <div className="cat-fields">
                    <input
                      className="field-input cat-field-sm"
                      value={c.emoji}
                      onChange={e => updateCat(i, 'emoji', e.target.value)}
                      placeholder="Emoji"
                    />
                    <input
                      className="field-input"
                      value={c.label}
                      onChange={e => updateCat(i, 'label', e.target.value)}
                      placeholder="Label"
                    />
                  </div>
                  <button className="btn btn-danger btn-sm" onClick={() => removeCat(i)}>✕</button>
                </div>
              ))}
              <button
                className="btn btn-ghost"
                style={{ marginTop: 14, width: '100%' }}
                onClick={saveCats}
                disabled={savingCats}
              >
                {savingCats ? 'Saving…' : 'Save All Categories'}
              </button>
            </div>
          )}
        </div>
      </div>

      {/* ── Modals ── */}
      {destModal !== null && (
        <DestModal
          item={destModal?.id ? destModal : null}
          onClose={() => setDestModal(null)}
          onSaved={async (msg) => { showToast(msg); await refresh(); }}
        />
      )}
      {agentModal !== null && (
        <AgentModal
          item={agentModal?.id ? agentModal : null}
          onClose={() => setAgentModal(null)}
          onSaved={async (msg) => { showToast(msg); await refresh(); }}
        />
      )}

      {/* ── Toast ── */}
      {toast && <Toast msg={toast} onDone={() => setToast(null)} />}
    </div>
  );
}
