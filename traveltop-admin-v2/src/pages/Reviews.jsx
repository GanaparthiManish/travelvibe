import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 20;

function StarBar({ value }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 3 }}>
      {[1, 2, 3, 4, 5].map(i => (
        <span key={i} style={{ color: i <= value ? '#f59e0b' : '#e5e7eb', fontSize: 12 }}>★</span>
      ))}
      <span style={{ fontSize: 12, color: 'var(--ink-soft)', marginLeft: 4 }}>{Number(value || 0).toFixed(1)}</span>
    </div>
  );
}

export default function Reviews() {
  const { toast } = useToast();
  const [activeTab, setActiveTab] = useState('agents'); // 'agents' | 'destinations'

  // Agent reviews state
  const [agentRows, setAgentRows] = useState([]);
  const [agentTotal, setAgentTotal] = useState(0);

  // Destination reviews state
  const [destRows, setDestRows] = useState([]);
  const [destTotal, setDestTotal] = useState(0);

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [previewImage, setPreviewImage] = useState(null);

  // Fetch Agent Reviews
  const fetchAgentReviews = useCallback(async () => {
    try {
      let q = supabase.from('reviews')
        .select(`*, traveller:profiles!traveller_id(full_name), agent:profiles!agent_id(full_name)`, { count: 'exact' });
      q = q.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
      const { data, count, error: err } = await q;
      if (err) throw err;
      setAgentRows(data || []);
      setAgentTotal(count || 0);
      setError(null);
    } catch (e) {
      try {
        let q = supabase.from('reviews').select('*', { count: 'exact' });
        q = q.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
        const { data, count } = await q;
        const uIds = [...new Set((data || []).flatMap(r => [r.traveller_id, r.agent_id]).filter(Boolean))];
        let pMap = {};
        if (uIds.length > 0) {
          const { data: pData } = await supabase.from('profiles').select('id, full_name').in('id', uIds);
          if (pData) pData.forEach(p => { pMap[p.id] = p; });
        }
        const formatted = (data || []).map(r => ({
          ...r,
          traveller: pMap[r.traveller_id] || { full_name: 'Traveller' },
          agent: pMap[r.agent_id] || { full_name: 'Agent' },
        }));
        setAgentRows(formatted);
        setAgentTotal(count || 0);
        setError(null);
      } catch (err2) {
        setError(err2.message);
      }
    }
  }, [page]);

  // Fetch Destination Reviews
  const fetchDestReviews = useCallback(async () => {
    try {
      let q = supabase.from('destination_reviews')
        .select(`*, traveller:profiles!traveller_id(full_name), destination:destinations!destination_id(name, country), destination_review_images(*)`, { count: 'exact' });
      q = q.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
      const { data, count, error: err } = await q;
      if (err) throw err;
      setDestRows(data || []);
      setDestTotal(count || 0);
      setError(null);
    } catch (e) {
      try {
        // Resilient fallback query
        let q = supabase.from('destination_reviews').select('*', { count: 'exact' });
        q = q.order('created_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
        const { data, count } = await q;
        if (!data) {
          setDestRows([]);
          setDestTotal(0);
          return;
        }

        const tIds = [...new Set((data || []).map(r => r.traveller_id).filter(Boolean))];
        const dIds = [...new Set((data || []).map(r => r.destination_id).filter(Boolean))];
        const revIds = (data || []).map(r => r.id);

        let pMap = {}, destMap = {}, imgMap = {};
        if (tIds.length > 0) {
          const { data: pData } = await supabase.from('profiles').select('id, full_name').in('id', tIds);
          if (pData) pData.forEach(p => { pMap[p.id] = p; });
        }
        if (dIds.length > 0) {
          const { data: dData } = await supabase.from('destinations').select('id, name, country').in('id', dIds);
          if (dData) dData.forEach(d => { destMap[d.id] = d; });
        }
        if (revIds.length > 0) {
          try {
            const { data: iData } = await supabase.from('destination_review_images').select('*').in('review_id', revIds);
            if (iData) {
              iData.forEach(img => {
                if (!imgMap[img.review_id]) imgMap[img.review_id] = [];
                imgMap[img.review_id].push(img);
              });
            }
          } catch (_) {}
        }

        const formatted = data.map(r => ({
          ...r,
          traveller: pMap[r.traveller_id] || { full_name: 'Traveller' },
          destination: destMap[r.destination_id] || { name: 'Destination' },
          destination_review_images: imgMap[r.id] || []
        }));

        setDestRows(formatted);
        setDestTotal(count || 0);
        setError(null);
      } catch (err2) {
        setError(err2.message);
      }
    }
  }, [page]);

  const loadCurrentTab = useCallback(async () => {
    setLoading(true);
    if (activeTab === 'agents') {
      await fetchAgentReviews();
    } else {
      await fetchDestReviews();
    }
    setLoading(false);
  }, [activeTab, fetchAgentReviews, fetchDestReviews]);

  useEffect(() => {
    loadCurrentTab();
  }, [loadCurrentTab]);

  // Realtime subscriptions
  useEffect(() => {
    const ch = supabase.channel('reviews_moderation_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'reviews' }, () => {
        if (activeTab === 'agents') fetchAgentReviews();
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'destination_reviews' }, () => {
        if (activeTab === 'destinations') fetchDestReviews();
      })
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, [activeTab, fetchAgentReviews, fetchDestReviews]);

  // Delete Agent Review
  async function deleteAgentReview(review) {
    const { id, agent_id } = review;
    await supabase.from('reviews').delete().eq('id', id);

    // Recalculate agent rating
    try {
      const { data: remaining } = await supabase.from('reviews').select('overall_rating').eq('agent_id', agent_id);
      if (remaining) {
        const count = remaining.length;
        const avg = count > 0 ? remaining.reduce((s, r) => s + (r.overall_rating || 0), 0) / count : 0;
        await supabase.from('agent_details').update({ rating_avg: avg, review_count: count }).eq('id', agent_id);
      }
    } catch (_) {}

    toast('Agent review deleted and rating recalculated', 'success');
    setDeleteTarget(null);
    fetchAgentReviews();
  }

  // Delete Destination Review
  async function deleteDestReview(review) {
    const { id, destination_id } = review;
    await supabase.from('destination_review_images').delete().eq('review_id', id);
    await supabase.from('destination_reviews').delete().eq('id', id);

    // Recalculate destination rating
    try {
      const { data: remaining } = await supabase.from('destination_reviews').select('rating').eq('destination_id', destination_id);
      if (remaining) {
        const count = remaining.length;
        const avg = count > 0 ? (remaining.reduce((s, r) => s + (r.rating || 0), 0) / count) : 0;
        await supabase.from('destinations').update({ rating_avg: avg, review_count: count }).eq('id', destination_id);
      }
    } catch (_) {}

    toast('Destination review removed and average recalculated', 'success');
    setDeleteTarget(null);
    fetchDestReviews();
  }

  // Filtered rows by search text
  const filteredAgentRows = agentRows.filter(r => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (
      (r.traveller?.full_name || '').toLowerCase().includes(s) ||
      (r.agent?.full_name || '').toLowerCase().includes(s) ||
      (r.review_text || '').toLowerCase().includes(s)
    );
  });

  const filteredDestRows = destRows.filter(r => {
    if (!search) return true;
    const s = search.toLowerCase();
    return (
      (r.traveller?.full_name || '').toLowerCase().includes(s) ||
      (r.destination?.name || '').toLowerCase().includes(s) ||
      (r.review_text || '').toLowerCase().includes(s)
    );
  });

  return (
    <div>
      {/* Tabs Header */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 16 }}>
        <button
          className={`btn ${activeTab === 'agents' ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => { setActiveTab('agents'); setPage(1); }}
          style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 700 }}
        >
          <span>👤 Guide & Agent Reviews</span>
          {agentTotal > 0 && <span style={{ opacity: 0.8, fontSize: 12 }}>({agentTotal})</span>}
        </button>
        <button
          className={`btn ${activeTab === 'destinations' ? 'btn-primary' : 'btn-ghost'}`}
          onClick={() => { setActiveTab('destinations'); setPage(1); }}
          style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 700 }}
        >
          <span>📍 Destination Reviews</span>
          {destTotal > 0 && <span style={{ opacity: 0.8, fontSize: 12 }}>({destTotal})</span>}
        </button>
      </div>

      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input
              className="search-input"
              placeholder={activeTab === 'agents' ? 'Search guide reviews…' : 'Search destination reviews…'}
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
        </div>

        {/* Tab 1: Agent Reviews */}
        {activeTab === 'agents' && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Traveller</th>
                  <th>Guide</th>
                  <th>Rating</th>
                  <th>Review</th>
                  <th>Date</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan={6}><Skeleton rows={6} cols={6} /></td></tr>
                ) : error ? (
                  <tr><td colSpan={6}><ErrorState message={error} onRetry={loadCurrentTab} /></td></tr>
                ) : filteredAgentRows.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="empty-state">
                        <div className="empty-state-icon">⭐</div>
                        <div className="empty-state-title">No guide reviews found</div>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filteredAgentRows.map(r => (
                    <tr key={r.id}>
                      <td style={{ fontWeight: 600 }}>{r.traveller?.full_name || '—'}</td>
                      <td className="cell-muted">{r.agent?.full_name || r.agent?.profiles?.full_name || '—'}</td>
                      <td><StarBar value={r.overall_rating || 0} /></td>
                      <td style={{ maxWidth: 280 }}>
                        <div style={{ fontSize: 12, color: 'var(--ink-soft)', overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', lineHeight: 1.5 }}>
                          {r.review_text || '—'}
                        </div>
                      </td>
                      <td className="cell-muted">{new Date(r.created_at).toLocaleDateString()}</td>
                      <td>
                        <button
                          className="btn btn-danger-text btn-xs"
                          onClick={() => setDeleteTarget({ type: 'agent', item: r })}
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
            <Pagination page={page} pageSize={PAGE_SIZE} total={agentTotal} onPage={setPage} />
          </div>
        )}

        {/* Tab 2: Destination Reviews */}
        {activeTab === 'destinations' && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Traveller</th>
                  <th>Destination</th>
                  <th>Rating</th>
                  <th>Review</th>
                  <th>Photos</th>
                  <th>Date</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan={7}><Skeleton rows={6} cols={7} /></td></tr>
                ) : error ? (
                  <tr><td colSpan={7}><ErrorState message={error} onRetry={loadCurrentTab} /></td></tr>
                ) : filteredDestRows.length === 0 ? (
                  <tr>
                    <td colSpan={7}>
                      <div className="empty-state">
                        <div className="empty-state-icon">📍</div>
                        <div className="empty-state-title">No destination reviews yet</div>
                        <div className="empty-state-desc">Verified travellers will submit reviews after completing their trips.</div>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filteredDestRows.map(r => {
                    const photos = r.destination_review_images || [];
                    return (
                      <tr key={r.id}>
                        <td style={{ fontWeight: 600 }}>{r.traveller?.full_name || '—'}</td>
                        <td style={{ fontWeight: 600, color: 'var(--primary, #0f766e)' }}>
                          {r.destination?.name || '—'}
                        </td>
                        <td><StarBar value={r.rating || 0} /></td>
                        <td style={{ maxWidth: 260 }}>
                          <div style={{ fontSize: 12, color: 'var(--ink-soft)', overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', lineHeight: 1.5 }}>
                            {r.review_text || '—'}
                          </div>
                        </td>
                        <td>
                          {photos.length > 0 ? (
                            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                              {photos.map(p => (
                                <img
                                  key={p.id}
                                  src={p.image_url}
                                  alt=""
                                  onClick={() => setPreviewImage(p.image_url)}
                                  style={{
                                    width: 38,
                                    height: 38,
                                    borderRadius: 6,
                                    objectFit: 'cover',
                                    cursor: 'pointer',
                                    border: '1px solid var(--line)'
                                  }}
                                />
                              ))}
                            </div>
                          ) : (
                            <span style={{ fontSize: 11, color: 'var(--ink-soft)' }}>No photos</span>
                          )}
                        </td>
                        <td className="cell-muted">{new Date(r.created_at).toLocaleDateString()}</td>
                        <td>
                          <button
                            className="btn btn-danger-text btn-xs"
                            onClick={() => setDeleteTarget({ type: 'destination', item: r })}
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
            <Pagination page={page} pageSize={PAGE_SIZE} total={destTotal} onPage={setPage} />
          </div>
        )}
      </div>

      {/* Delete Confirmation Dialog */}
      {deleteTarget && (
        <ConfirmDialog
          title={`Delete ${deleteTarget.type === 'agent' ? 'Guide' : 'Destination'} Review?`}
          description={`This review will be permanently deleted. The ${deleteTarget.type === 'agent' ? 'agent' : 'destination'} rating average and review count will automatically recalculate.`}
          confirmLabel="Delete Review"
          confirmClass="btn btn-primary"
          onConfirm={() => {
            if (deleteTarget.type === 'agent') {
              deleteAgentReview(deleteTarget.item);
            } else {
              deleteDestReview(deleteTarget.item);
            }
          }}
          onCancel={() => setDeleteTarget(null)}
        />
      )}

      {/* Full Image Preview Lightbox */}
      {previewImage && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.85)',
            zIndex: 3000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 24,
          }}
          onClick={() => setPreviewImage(null)}
        >
          <div style={{ position: 'relative', maxWidth: 800, maxHeight: '85vh' }}>
            <img
              src={previewImage}
              alt="Review Attachment"
              style={{ width: '100%', maxHeight: '85vh', objectFit: 'contain', borderRadius: 8 }}
            />
            <button
              onClick={() => setPreviewImage(null)}
              style={{
                position: 'absolute',
                top: 12,
                right: 12,
                background: 'rgba(0,0,0,0.6)',
                color: '#fff',
                border: 'none',
                borderRadius: '50%',
                width: 32,
                height: 32,
                fontSize: 16,
                cursor: 'pointer',
              }}
            >
              ✕
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
