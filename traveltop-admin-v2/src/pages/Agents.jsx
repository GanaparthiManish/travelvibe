import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import StatusBadge from '../components/StatusBadge';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 15;
const TABS = ['pending', 'approved', 'rejected', 'suspended'];
const TAB_LABELS = { pending: 'Pending Review', approved: 'Approved', rejected: 'Rejected', suspended: 'Suspended' };

function RejectReasonModal({ agent, onConfirm, onCancel }) {
  const [reason, setReason] = useState('');
  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onCancel()}>
      <div className="modal modal-sm" style={{ marginTop: 'auto', marginBottom: 'auto' }}>
        <div className="modal-header">
          <div className="modal-title">Reject Agent</div>
          <button className="modal-close" onClick={onCancel}>✕</button>
        </div>
        <div className="modal-body">
          <p style={{ fontSize: 13, color: 'var(--ink-soft)', marginBottom: 12 }}>
            Provide a reason for rejecting <strong>{agent?.profiles?.full_name}</strong>. This will be shown to the agent.
          </p>
          <div className="field-group">
            <label className="field-label">Rejection Reason *</label>
            <textarea className="field-input" rows={3} value={reason} onChange={e => setReason(e.target.value)}
              placeholder="e.g. Documents are unclear or incomplete…" />
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onCancel}>Cancel</button>
          <button className="btn btn-primary" style={{ background: 'var(--red)' }}
            disabled={!reason.trim()} onClick={() => onConfirm(reason)}>Reject Agent</button>
        </div>
      </div>
    </div>
  );
}

function AgentDetail({ agent, onBack, onAction }) {
  const profile = agent.profiles || {};
  const [docMap, setDocMap] = useState({ idProof: null, selfie: null, license: null });
  const [gallery, setGallery] = useState([]);
  const [loadingDocs, setLoadingDocs] = useState(true);
  const [payoutMethod, setPayoutMethod] = useState(null);
  const [loadingPayout, setLoadingPayout] = useState(true);
  const [updatingPayout, setUpdatingPayout] = useState(false);

  useEffect(() => {
    async function fetchPayout() {
      setLoadingPayout(true);
      try {
        const { data, error } = await supabase
          .from('agent_payout_methods')
          .select('*')
          .eq('agent_id', agent.id)
          .maybeSingle();
        if (!error && data) setPayoutMethod(data);
        else setPayoutMethod(null);
      } catch (_) {
        setPayoutMethod(null);
      } finally {
        setLoadingPayout(false);
      }
    }
    fetchPayout();
  }, [agent.id]);

  async function handleVerifyPayoutName(status) {
    setUpdatingPayout(true);
    try {
      const { error } = await supabase
        .from('agent_payout_methods')
        .update({ name_verified: status, updated_at: new Date().toISOString() })
        .eq('agent_id', agent.id);
      if (error) throw error;
      setPayoutMethod(prev => prev ? { ...prev, name_verified: status } : null);
    } catch (err) {
      alert('Failed to update payout verification: ' + err.message);
    } finally {
      setUpdatingPayout(false);
    }
  }

  useEffect(() => {
    async function fetchDocsAndGallery() {
      setLoadingDocs(true);
      try {
        async function resolveDoc(path, label) {
          if (!path) return null;
          if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('data:')) {
            return { url: path, label };
          }
          const cleanPath = path.replace(/^verification-docs\//, '').replace(/^\/+/, '');
          try {
            const { data } = await supabase.storage.from('verification-docs').createSignedUrl(cleanPath, 3600);
            return { url: data?.signedUrl || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${cleanPath}`, label };
          } catch (_) {
            return { url: `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${cleanPath}`, label };
          }
        }

        const map = { idProof: null, selfie: null, license: null };

        map.idProof = await resolveDoc(agent.id_proof_url || agent.verification_doc_url, 'Government ID Proof *');
        map.selfie = await resolveDoc(agent.selfie_url, 'Agent Selfie with ID *');
        map.license = await resolveDoc(agent.license_url, 'Tourism License / Registration');

        // Secondary check from agent_documents table
        try {
          const { data: docRows } = await supabase.from('agent_documents').select('*').eq('agent_id', agent.id);
          if (docRows && docRows.length > 0) {
            for (const d of docRows) {
              if (d.document_type === 'id_proof' && !map.idProof) map.idProof = await resolveDoc(d.file_url, 'Government ID Proof *');
              if (d.document_type === 'selfie' && !map.selfie) map.selfie = await resolveDoc(d.file_url, 'Agent Selfie with ID *');
              if (d.document_type === 'license' && !map.license) map.license = await resolveDoc(d.file_url, 'Tourism License / Registration');
            }
          }
        } catch (_) {}

        setDocMap(map);

        // 2. Fetch Trip Gallery from public agent_gallery table or agent.gallery_urls fallback
        try {
          const { data: galData } = await supabase
            .from('agent_gallery')
            .select('*')
            .eq('agent_id', agent.id)
            .order('display_order', { ascending: true });
          
          if (galData && galData.length > 0) {
            setGallery(galData);
          } else if (agent.gallery_urls && Array.isArray(agent.gallery_urls) && agent.gallery_urls.length > 0) {
            setGallery(agent.gallery_urls.map((url, i) => ({ id: i, image_url: url })));
          } else {
            setGallery([]);
          }
        } catch (_) {
          if (agent.gallery_urls && Array.isArray(agent.gallery_urls) && agent.gallery_urls.length > 0) {
            setGallery(agent.gallery_urls.map((url, i) => ({ id: i, image_url: url })));
          } else {
            setGallery([]);
          }
        }
      } catch (e) {
        console.error('Error loading agent media:', e);
      } finally {
        setLoadingDocs(false);
      }
    }
    fetchDocsAndGallery();
  }, [agent]);

  const isPending = agent.verification_status === 'pending' || agent.verification_status === 'under_review';

  return (
    <div>
      <button className="back-btn" onClick={onBack}>← Back to Agents</button>
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            {profile.photo_url ? (
              <img
                src={profile.photo_url}
                className="avatar"
                style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: '50%' }}
                alt=""
                onError={e => {
                  e.currentTarget.style.display = 'none';
                  const next = e.currentTarget.parentElement?.querySelector('.avatar-fallback');
                  if (next) next.style.display = 'flex';
                }}
              />
            ) : null}
            <div
              className="avatar-fallback"
              style={{
                width: 56,
                height: 56,
                borderRadius: '50%',
                display: profile.photo_url ? 'none' : 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: 20,
                fontWeight: 700,
              }}
            >
              {(profile.full_name || 'A')[0]}
            </div>
            <div>
              <div style={{ fontWeight: 800, fontSize: 18 }}>{profile.full_name || '—'}</div>
              <div className="cell-muted">{profile.email || '—'} · {profile.phone ? profile.phone : 'N/A'}</div>

            </div>
          </div>
          <div className="action-row">
            {isPending && (
              <>
                <button className="btn btn-primary btn-sm" onClick={() => onAction('approve', agent)}>✓ Approve Agent</button>
                <button className="btn btn-danger-text btn-sm" onClick={() => onAction('reject', agent)}>✕ Reject</button>
              </>
            )}
            {agent.verification_status === 'approved' && !agent.suspended && (
              <button className="btn btn-danger-text btn-sm" onClick={() => onAction('suspend', agent)}>Suspend</button>
            )}
            {agent.suspended && (
              <button className="btn btn-secondary btn-sm" onClick={() => onAction('unsuspend', agent)}>Unsuspend</button>
            )}
            {agent.verification_status === 'rejected' && (
              <button className="btn btn-secondary btn-sm" onClick={() => onAction('approve', agent)}>Approve Anyway</button>
            )}
          </div>
        </div>
        <div className="card-body">

          {/* SECTION 1: VERIFICATION DOCUMENTS (PRIVATE — TOP PRIORITY FOR ADMIN REVIEW) */}
          <div style={{ background: '#f8fafc', border: '1.5px solid #cbd5e1', borderRadius: 10, padding: 16, marginBottom: 20 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
              <div style={{ fontWeight: 800, fontSize: 14, color: '#0f172a', display: 'flex', alignItems: 'center', gap: 6 }}>
                <span>🔒</span> Private Verification Documents (Admin Review Only)
              </div>
              <span style={{ fontSize: 10, fontWeight: 800, background: '#fef2f2', color: '#dc2626', padding: '2px 8px', borderRadius: 4 }}>
                PRIVATE BUCKET
              </span>
            </div>

            {loadingDocs ? (
              <div style={{ fontSize: 13, color: 'var(--ink-soft)' }}>Generating secure document signed URLs…</div>
            ) : (
              <div className="doc-preview-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 14 }}>
                {/* ID Proof */}
                <div className="doc-preview-card" style={{ border: '1px solid #e2e8f0', borderRadius: 8, overflow: 'hidden', background: '#fff' }}>
                  <div style={{ padding: '8px 10px', fontSize: 12, fontWeight: 700, color: '#334155', background: '#f1f5f9', borderBottom: '1px solid #e2e8f0' }}>
                    Government ID Proof *
                  </div>
                  {docMap.idProof || agent.id_proof_url ? (
                    (docMap.idProof?.url || agent.id_proof_url || '').toLowerCase().includes('.pdf') ? (
                      <div style={{ height: 130, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, padding: 8 }}>
                        <span style={{ fontSize: 28 }}>📄</span>
                        <div style={{ fontSize: 11, fontWeight: 600, color: '#475569', textAlign: 'center' }}>PDF Document Attached</div>
                        <a href={docMap.idProof?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.id_proof_url}`}
                           target="_blank" rel="noreferrer" className="btn btn-primary btn-xs">Open ID PDF ↗</a>
                      </div>
                    ) : (
                      <div style={{ position: 'relative', height: 130 }}>
                        <img src={docMap.idProof?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.id_proof_url}`}
                             alt="ID Proof" style={{ width: '100%', height: 130, objectFit: 'cover', cursor: 'pointer' }}
                             onClick={() => window.open(docMap.idProof?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.id_proof_url}`, '_blank')} />
                      </div>
                    )
                  ) : (
                    <div style={{ height: 130, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 12 }}>
                      Not Provided
                    </div>
                  )}
                </div>

                {/* Selfie */}
                <div className="doc-preview-card" style={{ border: '1px solid #e2e8f0', borderRadius: 8, overflow: 'hidden', background: '#fff' }}>
                  <div style={{ padding: '8px 10px', fontSize: 12, fontWeight: 700, color: '#334155', background: '#f1f5f9', borderBottom: '1px solid #e2e8f0' }}>
                    Agent Selfie with ID *
                  </div>
                  {docMap.selfie || agent.selfie_url ? (
                    <div style={{ position: 'relative', height: 130 }}>
                      <img src={docMap.selfie?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.selfie_url}`}
                           alt="Selfie" style={{ width: '100%', height: 130, objectFit: 'cover', cursor: 'pointer' }}
                           onClick={() => window.open(docMap.selfie?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.selfie_url}`, '_blank')} />
                    </div>
                  ) : (
                    <div style={{ height: 130, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 12 }}>
                      Not Provided
                    </div>
                  )}
                </div>

                {/* License (Optional) */}
                <div className="doc-preview-card" style={{ border: '1px solid #e2e8f0', borderRadius: 8, overflow: 'hidden', background: '#fff' }}>
                  <div style={{ padding: '8px 10px', fontSize: 12, fontWeight: 700, color: '#334155', background: '#f1f5f9', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between' }}>
                    <span>Tourism License</span>
                    <span style={{ fontSize: 10, color: '#64748b' }}>Optional</span>
                  </div>
                  {docMap.license || agent.license_url ? (
                    (docMap.license?.url || agent.license_url || '').toLowerCase().includes('.pdf') ? (
                      <div style={{ height: 130, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, padding: 8 }}>
                        <span style={{ fontSize: 28 }}>📄</span>
                        <div style={{ fontSize: 11, fontWeight: 600, color: '#475569', textAlign: 'center' }}>PDF Document Attached</div>
                        <a href={docMap.license?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.license_url}`}
                           target="_blank" rel="noreferrer" className="btn btn-primary btn-xs">Open License PDF ↗</a>
                      </div>
                    ) : (
                      <img src={docMap.license?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.license_url}`}
                           alt="License" style={{ width: '100%', height: 130, objectFit: 'cover', cursor: 'pointer' }}
                           onClick={() => window.open(docMap.license?.url || `https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/${agent.license_url}`, '_blank')} />
                    )
                  ) : (
                    <div style={{ height: 130, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#94a3b8', fontSize: 12 }}>
                      Not Provided
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* SECTION 1.5: PAYOUT METHOD (BANK/UPI) & NAME VERIFICATION */}
          <div style={{ background: '#f8fafc', border: '1.5px solid #cbd5e1', borderRadius: 10, padding: 16, marginBottom: 20 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
              <div style={{ fontWeight: 800, fontSize: 14, color: '#0f172a', display: 'flex', alignItems: 'center', gap: 6 }}>
                <span>💳</span> Linked Payout Method (Bank / UPI)
              </div>
              {payoutMethod ? (
                payoutMethod.name_verified ? (
                  <span className="badge badge-green" style={{ fontSize: 11, fontWeight: 700 }}>
                    <span className="badge-dot" /> Name Verified
                  </span>
                ) : (
                  <span className="badge badge-red" style={{ fontSize: 11, fontWeight: 700 }}>
                    <span className="badge-dot" /> Mismatch / Review Required
                  </span>
                )
              ) : (
                <span className="badge badge-gray" style={{ fontSize: 11 }}>No Method Added</span>
              )}
            </div>

            {loadingPayout ? (
              <div style={{ fontSize: 13, color: 'var(--ink-soft)' }}>Checking payout method…</div>
            ) : payoutMethod ? (
              <div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginBottom: 14 }}>
                  <div className="detail-item">
                    <div className="detail-item-label">Payout Type</div>
                    <div className="detail-item-value" style={{ textTransform: 'uppercase', fontWeight: 700 }}>
                      {payoutMethod.method_type}
                    </div>
                  </div>

                  <div className="detail-item">
                    <div className="detail-item-label">Account Holder Name</div>
                    <div className="detail-item-value" style={{ fontWeight: 700 }}>
                      {payoutMethod.account_holder_name}
                    </div>
                  </div>

                  {payoutMethod.method_type === 'bank' ? (
                    <>
                      <div className="detail-item">
                        <div className="detail-item-label">Bank Account Number</div>
                        <div className="detail-item-value" style={{ fontFamily: 'monospace', fontWeight: 600 }}>
                          {payoutMethod.bank_account_number || '—'}
                        </div>
                      </div>
                      <div className="detail-item">
                        <div className="detail-item-label">IFSC Code</div>
                        <div className="detail-item-value" style={{ fontFamily: 'monospace', fontWeight: 600 }}>
                          {payoutMethod.ifsc_code || '—'}
                        </div>
                      </div>
                    </>
                  ) : (
                    <div className="detail-item">
                      <div className="detail-item-label">UPI ID (VPA)</div>
                      <div className="detail-item-value" style={{ fontWeight: 600, color: '#166534' }}>
                        {payoutMethod.upi_id || '—'}
                      </div>
                    </div>
                  )}
                </div>

                {/* Name Match Alert Box */}
                {!payoutMethod.name_verified ? (
                  <div style={{ background: '#fff1f2', border: '1px solid #fecdd3', borderRadius: 8, padding: '12px 16px', marginBottom: 12 }}>
                    <div style={{ fontWeight: 700, color: '#e11d48', fontSize: 13, display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                      <span>⚠️</span> Payout name mismatch — Entered: "{payoutMethod.account_holder_name}" vs Verified ID: "{profile.full_name || 'Unset'}"
                    </div>
                    <p style={{ margin: 0, fontSize: 12, color: '#9f1239', lineHeight: 1.5 }}>
                      Automatic payout releases for this agent are currently <strong>blocked</strong>. Review their submitted ID proof above. If the name difference is a minor spelling discrepancy or joint account, you may manually approve below.
                    </p>
                    <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                      <button
                        className="btn btn-secondary btn-sm"
                        style={{ color: '#047857', borderColor: '#a7f3d0' }}
                        disabled={updatingPayout}
                        onClick={() => handleVerifyPayoutName(true)}
                      >
                        ✓ Approve Payout Name
                      </button>
                      <button
                        className="btn btn-secondary btn-sm"
                        style={{ color: '#dc2626', borderColor: '#fecaca' }}
                        disabled={updatingPayout}
                        onClick={() => handleVerifyPayoutName(false)}
                      >
                        ✕ Reject Name
                      </button>
                    </div>
                  </div>
                ) : (
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: 8, padding: '10px 14px' }}>
                    <div style={{ fontSize: 12, color: '#166534', fontWeight: 600 }}>
                      ✓ Payout method verified. Escrow payouts will release automatically when trip milestones are met.
                    </div>
                    <button
                      className="btn btn-secondary btn-xs"
                      style={{ color: '#dc2626', borderColor: '#fecaca' }}
                      disabled={updatingPayout}
                      onClick={() => handleVerifyPayoutName(false)}
                    >
                      Revoke Verification
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div style={{ fontSize: 13, color: 'var(--ink-soft)' }}>
                Agent has not added a Bank Account or UPI ID yet. They must add it under Settings → Payout Method in the Agent app before payouts can release.
              </div>
            )}
          </div>

          {/* SECTION 2: AGENT PROFILE DETAILS */}
          <div className="detail-grid" style={{ marginBottom: 20 }}>
            <div className="detail-item"><div className="detail-item-label">Verification Status</div><StatusBadge status={agent.suspended ? 'suspended' : agent.verification_status} /></div>
            <div className="detail-item"><div className="detail-item-label">Verified Badge</div><StatusBadge status={agent.verified ? 'verified' : 'inactive'} /></div>
            <div className="detail-item"><div className="detail-item-label">Rating</div><div className="detail-item-value">⭐ {agent.rating_avg?.toFixed(1) || '—'} ({agent.review_count || 0} reviews)</div></div>
            <div className="detail-item"><div className="detail-item-label">Price / Day</div><div className="detail-item-value">₹{(agent.price_per_day || 0).toLocaleString('en-IN')}</div></div>
            <div className="detail-item"><div className="detail-item-label">Experience</div><div className="detail-item-value">{agent.years_experience} years</div></div>
            <div className="detail-item"><div className="detail-item-label">Languages</div><div className="detail-item-value">{(agent.languages || []).join(', ') || '—'}</div></div>
            <div className="detail-item"><div className="detail-item-label">Meals Included</div><StatusBadge status={agent.meals_included ? 'active' : 'inactive'} label={agent.meals_included ? 'Yes' : 'No'} /></div>
            <div className="detail-item"><div className="detail-item-label">Accommodation</div><StatusBadge status={agent.accommodation_included ? 'active' : 'inactive'} label={agent.accommodation_included ? 'Yes' : 'No'} /></div>
          </div>
          <div className="detail-item" style={{ marginBottom: 16 }}>
            <div className="detail-item-label">Places Covered</div>
            <div className="detail-item-value">{(agent.places_covered || []).join(', ') || '—'}</div>
          </div>
          {agent.bio && (
            <div className="detail-item" style={{ marginBottom: 16 }}>
              <div className="detail-item-label">Bio</div>
              <div className="detail-item-value" style={{ lineHeight: 1.6 }}>{agent.bio}</div>
            </div>
          )}
          {agent.rejection_reason && (
            <div style={{ background: 'var(--red-light)', border: '1px solid #fca5a5', borderRadius: 8, padding: '12px 14px', marginBottom: 16 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--red)', marginBottom: 4 }}>REJECTION REASON</div>
              <div style={{ fontSize: 13, color: 'var(--red)' }}>{agent.rejection_reason}</div>
            </div>
          )}

          {/* SECTION 3: TRIP GALLERY (PUBLIC PORTFOLIO) */}
          <div style={{ marginTop: 20 }}>
            <div className="section-title" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span>📷 Trip Gallery Portfolio (Public Facing)</span>
              <span style={{ fontSize: 11, color: '#16a34a', background: '#dcfce7', padding: '2px 8px', borderRadius: 4, fontWeight: 700 }}>
                PUBLIC BUCKET
              </span>
            </div>
            {gallery.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))', gap: 10, marginTop: 10 }}>
                {gallery.map((g, i) => {
                  const url = g.image_url || g;
                  const isVideo = typeof url === 'string' && (/\.(mp4|mov|webm|avi|mkv)$/i.test(url) || url.includes('/video/'));
                  if (isVideo) {
                    return (
                      <div key={g.id || i} style={{ position: 'relative', width: '100%', height: 100, borderRadius: 8, background: '#0f172a', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', overflow: 'hidden' }} onClick={() => window.open(url, '_blank')}>
                        <video src={url} style={{ width: '100%', height: '100%', objectFit: 'cover', opacity: 0.7 }} muted />
                        <div style={{ position: 'absolute', color: '#fff', fontSize: 24, fontWeight: 'bold' }}>▶</div>
                        <span style={{ position: 'absolute', bottom: 4, right: 4, background: '#ef4444', color: '#fff', fontSize: 9, padding: '1px 5px', borderRadius: 4, fontWeight: 700 }}>30s Video</span>
                      </div>
                    );
                  }
                  return (
                    <img key={g.id || i} src={url} alt={`Gallery ${i+1}`}
                      style={{ width: '100%', height: 100, objectFit: 'cover', borderRadius: 8, cursor: 'pointer' }}
                      onClick={() => window.open(url, '_blank')} />
                  );
                })}
              </div>
            ) : (
              <div style={{ fontSize: 13, color: 'var(--ink-soft)', fontStyle: 'italic', marginTop: 6 }}>
                No trip portfolio photos or videos uploaded yet.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function Agents() {
  const { toast } = useToast();
  const [tab, setTab] = useState('pending');
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selectedAgent, setSelectedAgent] = useState(null);
  const [rejectTarget, setRejectTarget] = useState(null);
  const [suspendConfirm, setSuspendConfirm] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      let q = supabase.from('agent_details').select('*', { count: 'exact' });

      if (tab === 'suspended') {
        q = q.eq('suspended', true);
      } else if (tab === 'pending') {
        q = q.or('verification_status.eq.pending,verification_status.eq.under_review,verification_status.eq.unverified,verification_status.is.null').or('suspended.eq.false,suspended.is.null');
      } else {
        q = q.eq('verification_status', tab).or('suspended.eq.false,suspended.is.null');
      }

      q = q.order('id', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

      const { data, count, error: err } = await q;
      if (err) throw err;

      // Fetch profile info for each agent
      const agentIds = [...new Set((data || []).map(a => a.id).filter(id => id && id.length > 5))];
      let profilesMap = {};
      if (agentIds.length > 0) {
        const { data: pData } = await supabase.from('profiles').select('id, full_name, email, phone, photo_url').in('id', agentIds);
        if (pData) {
          pData.forEach(p => { profilesMap[p.id] = p; });
        }
      }

      const formatted = (data || []).map(a => ({
        ...a,
        profiles: profilesMap[a.id] || { full_name: 'Agent User', email: a.id }
      }));

      setRows(formatted);
      setTotal(count || 0);
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [tab, page, search]);

  useEffect(() => { fetchData(); }, [fetchData]);

  useEffect(() => {
    const ch = supabase.channel('agents_rt_all')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_details' }, fetchData)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, fetchData)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_gallery' }, fetchData)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_documents' }, fetchData)
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, [fetchData]);

  async function handleAction(action, agent) {
    if (action === 'reject') { setRejectTarget(agent); return; }
    if (action === 'suspend') { setSuspendConfirm({ action: 'suspend', agent }); return; }
    if (action === 'unsuspend') { setSuspendConfirm({ action: 'unsuspend', agent }); return; }
    await applyAction(action, agent);
  }

  async function applyAction(action, agent, reason = '') {
    const id = agent.id;
    if (action === 'approve') {
      await supabase.from('agent_details').update({ verification_status: 'approved', verified: true, suspended: false }).eq('id', id);
      await supabase.from('profiles').update({ suspended: false, role: 'agent' }).eq('id', id);
      toast(`${agent.profiles?.full_name} approved ✓`, 'success');
    } else if (action === 'reject') {
      await supabase.from('agent_details').update({ verification_status: 'rejected', rejection_reason: reason, verified: false }).eq('id', id);
      await supabase.from('profiles').update({ role: 'agent' }).eq('id', id);
      toast(`${agent.profiles?.full_name} rejected`, 'success');
    } else if (action === 'suspend') {
      await supabase.from('agent_details').update({ suspended: true }).eq('id', id);
      await supabase.from('profiles').update({ suspended: true, role: 'agent' }).eq('id', id);
      toast(`${agent.profiles?.full_name} suspended`, 'success');
    } else if (action === 'unsuspend') {
      await supabase.from('agent_details').update({ suspended: false }).eq('id', id);
      await supabase.from('profiles').update({ suspended: false, role: 'agent' }).eq('id', id);
      toast(`${agent.profiles?.full_name} unsuspended`, 'success');
    }

    // Broadcast instant real-time sync event across all web app clients
    try {
      const syncCh = supabase.channel('global_admin_sync');
      syncCh.subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          syncCh.send({
            type: 'broadcast',
            event: 'agent_status_changed',
            payload: {
              id,
              action,
              suspended: action === 'suspend',
              timestamp: Date.now()
            }
          });
        }
      });
    } catch (bErr) {
      console.warn('Realtime broadcast error:', bErr);
    }
    setRejectTarget(null); setSuspendConfirm(null);
    if (selectedAgent?.id === id) setSelectedAgent(null);
    fetchData();
  }

  if (selectedAgent) {
    return <AgentDetail agent={selectedAgent} onBack={() => setSelectedAgent(null)} onAction={handleAction} />;
  }

  return (
    <div>
      <div className="card">
        <div className="tabs">
          {TABS.map(t => (
            <button key={t} className={`tab${tab === t ? ' active' : ''}`} onClick={() => { setTab(t); setPage(1); }}>
              {TAB_LABELS[t]}
            </button>
          ))}
        </div>

        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search agents…" value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>Agent</th>
              <th>Places Covered</th>
              <th>Rating</th>
              <th>Price/Day</th>
              <th>Status</th>
              <th>Actions</th>
            </tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={6}><Skeleton rows={8} cols={6} /></td></tr>
                : error ? <tr><td colSpan={6}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={6}>
                    <div className="empty-state">
                      <div className="empty-state-icon">🧑‍💼</div>
                      <div className="empty-state-title">No {TAB_LABELS[tab].toLowerCase()} agents</div>
                    </div>
                  </td></tr>
                ) : rows.map(a => (
                  <tr key={a.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedAgent(a)}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        {a.profiles?.photo_url ? (
                          <img
                            src={a.profiles.photo_url}
                            className="avatar"
                            style={{ width: 34, height: 34, objectFit: 'cover', borderRadius: '50%' }}
                            alt=""
                            onError={e => {
                              e.currentTarget.style.display = 'none';
                              const next = e.currentTarget.parentElement?.querySelector('.avatar-fallback');
                              if (next) next.style.display = 'flex';
                            }}
                          />
                        ) : null}
                        <div
                          className="avatar-fallback"
                          style={{
                            width: 34,
                            height: 34,
                            borderRadius: '50%',
                            display: a.profiles?.photo_url ? 'none' : 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: 14,
                            fontWeight: 700,
                          }}
                        >
                          {(a.profiles?.full_name || 'A')[0]}
                        </div>

                        <div>
                          <div style={{ fontWeight: 600 }}>{a.profiles?.full_name || '—'}</div>
                          <div className="cell-muted">{a.profiles?.email}</div>
                        </div>
                      </div>
                    </td>
                    <td className="cell-muted" style={{ maxWidth: 180 }}>
                      {(a.places_covered || []).slice(0, 3).join(', ')}
                      {(a.places_covered || []).length > 3 && ` +${a.places_covered.length - 3}`}
                    </td>
                    <td>⭐ {a.rating_avg ? Number(a.rating_avg).toFixed(1) : '—'}</td>
                    <td>₹{(a.price_per_day || 0).toLocaleString('en-IN')}</td>
                    <td onClick={e => e.stopPropagation()}>
                      <StatusBadge status={a.suspended ? 'suspended' : a.verification_status} />
                    </td>
                    <td onClick={e => e.stopPropagation()}>
                      <div className="action-row">
                        {tab === 'pending' && (
                          <>
                            <button className="btn btn-primary btn-xs" onClick={() => applyAction('approve', a)}>Approve</button>
                            <button className="btn btn-danger-text btn-xs" onClick={() => handleAction('reject', a)}>Reject</button>
                          </>
                        )}
                        {tab === 'approved' && (
                          <button className="btn btn-danger-text btn-xs" onClick={() => handleAction('suspend', a)}>Suspend</button>
                        )}
                        {tab === 'suspended' && (
                          <button className="btn btn-ghost btn-xs" onClick={() => handleAction('unsuspend', a)}>Unsuspend</button>
                        )}
                        {tab === 'rejected' && (
                          <button className="btn btn-ghost btn-xs" onClick={() => applyAction('approve', a)}>Approve</button>
                        )}
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

      {rejectTarget && (
        <RejectReasonModal agent={rejectTarget}
          onConfirm={reason => applyAction('reject', rejectTarget, reason)}
          onCancel={() => setRejectTarget(null)} />
      )}

      {suspendConfirm && (
        <ConfirmDialog
          title={suspendConfirm.action === 'suspend' ? 'Suspend Agent?' : 'Unsuspend Agent?'}
          description={suspendConfirm.action === 'suspend'
            ? `${suspendConfirm.agent.profiles?.full_name} will be removed from traveller listings immediately.`
            : `${suspendConfirm.agent.profiles?.full_name} will be restored to traveller listings.`
          }
          confirmLabel={suspendConfirm.action === 'suspend' ? 'Suspend' : 'Unsuspend'}
          confirmClass={suspendConfirm.action === 'suspend' ? 'btn btn-primary' : 'btn btn-secondary'}
          onConfirm={() => applyAction(suspendConfirm.action, suspendConfirm.agent)}
          onCancel={() => setSuspendConfirm(null)}
        />
      )}
    </div>
  );
}
