import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import StatusBadge from '../components/StatusBadge';
import ConfirmDialog from '../components/ConfirmDialog';

const PAGE_SIZE = 20;

export default function Payouts() {
  const { toast } = useToast();
  const [rows, setRows] = useState([]);
  const [payoutMethods, setPayoutMethods] = useState({});
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [payTarget, setPayTarget] = useState(null);
  const [paying, setPaying] = useState({});
  const [updatingMethod, setUpdatingMethod] = useState({});

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      let q = supabase.from('payouts').select('*', { count: 'exact' });
      if (statusFilter !== 'all') q = q.eq('status', statusFilter);
      q = q.order('requested_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
      const { data, count, error: err } = await q;
      if (err) throw err;

      const agentIds = [...new Set((data || []).map(p => p.agent_id).filter(Boolean))];
      let pMap = {};
      let methodMap = {};

      if (agentIds.length > 0) {
        // 1. Fetch Agent Profiles
        const { data: pData } = await supabase.from('profiles').select('id, full_name, email, phone').in('id', agentIds);
        if (pData) {
          pData.forEach(p => { pMap[p.id] = p; });
        }

        // 2. Fetch Agent Payout Methods
        try {
          const { data: mData } = await supabase.from('agent_payout_methods').select('*').in('agent_id', agentIds);
          if (mData) {
            mData.forEach(m => { methodMap[m.agent_id] = m; });
          }
        } catch (_) {
          // In case table not yet created in remote DB
        }
      }

      const formatted = (data || []).map(p => ({
        ...p,
        profiles: pMap[p.agent_id] || null,
        payout_method: methodMap[p.agent_id] || null,
      }));

      // Filter by search if provided
      const filtered = search.trim()
        ? formatted.filter(p => {
            const name = (p.profiles?.full_name || '').toLowerCase();
            const email = (p.profiles?.email || '').toLowerCase();
            const holder = (p.payout_method?.account_holder_name || '').toLowerCase();
            const qStr = search.toLowerCase();
            return name.includes(qStr) || email.includes(qStr) || holder.includes(qStr);
          })
        : formatted;

      setRows(filtered);
      setPayoutMethods(methodMap);
      setTotal(count || 0);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, search]);

  useEffect(() => { fetchData(); }, [fetchData]);

  useEffect(() => {
    const ch = supabase.channel('admin_payouts_all_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'payouts' }, fetchData)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'agent_payout_methods' }, fetchData)
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, [fetchData]);

  async function markPaid(payout) {
    setPaying(prev => ({ ...prev, [payout.id]: true }));
    try {
      const { error: updErr } = await supabase
        .from('payouts')
        .update({ status: 'paid', paid_at: new Date().toISOString() })
        .eq('id', payout.id);
      if (updErr) throw updErr;
      toast(`Payout of ₹${(payout.amount || 0).toLocaleString('en-IN')} marked as paid`, 'success');
      setPayTarget(null);
      fetchData();
    } catch (e) {
      toast(`Error updating payout: ${e.message}`, 'error');
    } finally {
      setPaying(prev => ({ ...prev, [payout.id]: false }));
    }
  }

  async function handleVerifyName(agentId, verifyStatus) {
    setUpdatingMethod(prev => ({ ...prev, [agentId]: true }));
    try {
      const { error: updErr } = await supabase
        .from('agent_payout_methods')
        .update({ name_verified: verifyStatus, updated_at: new Date().toISOString() })
        .eq('agent_id', agentId);
      if (updErr) throw updErr;

      toast(
        verifyStatus ? 'Payout method name verified & approved!' : 'Payout method name rejected / flagged.',
        verifyStatus ? 'success' : 'warning'
      );
      fetchData();
    } catch (e) {
      toast(`Error: ${e.message}`, 'error');
    } finally {
      setUpdatingMethod(prev => ({ ...prev, [agentId]: false }));
    }
  }

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input
              className="search-input"
              placeholder="Search by agent name, email, or account holder…"
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
            />
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {['all', 'processing', 'paid'].map(s => (
              <button
                key={s}
                className={`filter-chip${statusFilter === s ? ' active' : ''}`}
                onClick={() => { setStatusFilter(s); setPage(1); }}
              >
                {s === 'processing' ? 'Processing' : s.charAt(0).toUpperCase() + s.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Agent</th>
                <th>Stage / Details</th>
                <th>Amount</th>
                <th>Payout Method & Name Verification</th>
                <th>Status</th>
                <th>Requested</th>
                <th>Paid At</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={8}><Skeleton rows={6} cols={8} /></td></tr>
              ) : error ? (
                <tr><td colSpan={8}><ErrorState message={error} onRetry={fetchData} /></td></tr>
              ) : rows.length === 0 ? (
                <tr>
                  <td colSpan={8}>
                    <div className="empty-state">
                      <div className="empty-state-icon">💸</div>
                      <div className="empty-state-title">No payout requests found</div>
                    </div>
                  </td>
                </tr>
              ) : (
                rows.map(p => {
                  const method = p.payout_method;
                  const isVerified = method?.name_verified;
                  const hasMethod = !!method;
                  const verifiedIdName = p.profiles?.full_name || 'Verified ID Name Unavailable';
                  const stageLabel = p.payout_stage === 1
                    ? 'Stage 1: Trip Start (30%)'
                    : p.payout_stage === 2
                    ? 'Stage 2: Daily Progress'
                    : p.payout_stage === 3
                    ? 'Stage 3: Completion (40%)'
                    : 'Standard / Ad-hoc';

                  return (
                    <tr key={p.id}>
                      <td>
                        <div style={{ fontWeight: 700, color: 'var(--ink)' }}>
                          {p.profiles?.full_name || 'Agent'}
                        </div>
                        <div style={{ fontSize: 11, color: 'var(--ink-soft)' }}>
                          {p.profiles?.email || '—'}
                        </div>
                      </td>

                      <td>
                        <div style={{ fontSize: 12, fontWeight: 700, color: p.payout_stage ? '#4338ca' : 'var(--ink)' }}>
                          {stageLabel}
                        </div>
                        {p.notes && (
                          <div style={{ fontSize: 11, color: 'var(--ink-soft)', marginTop: 2 }}>
                            {p.notes}
                          </div>
                        )}
                      </td>

                      <td style={{ fontWeight: 800, fontSize: 15, color: '#047857' }}>
                        ₹{(p.amount || 0).toLocaleString('en-IN')}
                      </td>

                      <td style={{ minWidth: 220 }}>
                        {hasMethod ? (
                          <div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                              <span style={{
                                fontSize: 11,
                                fontWeight: 700,
                                textTransform: 'uppercase',
                                padding: '2px 6px',
                                borderRadius: 4,
                                background: method.method_type === 'upi' ? '#f0fdf4' : '#eff6ff',
                                color: method.method_type === 'upi' ? '#166534' : '#1e40af',
                                border: `1px solid ${method.method_type === 'upi' ? '#bbf7d0' : '#bfdbfe'}`
                              }}>
                                {method.method_type === 'upi' ? 'UPI' : 'Bank'}
                              </span>

                              {isVerified ? (
                                <span className="badge badge-green" style={{ fontSize: 10 }}>
                                  <span className="badge-dot" /> Name Verified
                                </span>
                              ) : (
                                <span className="badge badge-red" style={{ fontSize: 10 }}>
                                  <span className="badge-dot" /> Mismatch / Review
                                </span>
                              )}
                            </div>

                            <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--ink)' }}>
                              {method.method_type === 'bank'
                                ? `A/C: ${method.bank_account_number ? '••••' + method.bank_account_number.slice(-4) : '—'} (IFSC: ${method.ifsc_code || '—'})`
                                : `VPA: ${method.upi_id || '—'}`
                              }
                            </div>

                            {/* Name Comparison */}
                            <div style={{ fontSize: 11, marginTop: 4, padding: '4px 8px', borderRadius: 6, background: isVerified ? '#f8fafc' : '#fff1f2', border: `1px solid ${isVerified ? '#e2e8f0' : '#fecdd3'}` }}>
                              <div>Holder: <strong style={{ color: isVerified ? 'var(--ink)' : '#e11d48' }}>{method.account_holder_name}</strong></div>
                              <div>ID Name: <span style={{ color: 'var(--ink-soft)' }}>{verifiedIdName}</span></div>
                            </div>

                            {/* Admin Quick Action for Name Review */}
                            {!isVerified && (
                              <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
                                <button
                                  className="btn btn-secondary btn-xs"
                                  style={{ color: '#047857', borderColor: '#a7f3d0' }}
                                  disabled={updatingMethod[method.agent_id]}
                                  onClick={() => handleVerifyName(method.agent_id, true)}
                                >
                                  ✓ Approve Name
                                </button>
                                <button
                                  className="btn btn-secondary btn-xs"
                                  style={{ color: '#dc2626', borderColor: '#fecaca' }}
                                  disabled={updatingMethod[method.agent_id]}
                                  onClick={() => handleVerifyName(method.agent_id, false)}
                                >
                                  ✕ Reject
                                </button>
                              </div>
                            )}
                          </div>
                        ) : (
                          <div style={{ fontSize: 12, color: '#dc2626', fontWeight: 600 }}>
                            ⚠️ No payout method linked
                          </div>
                        )}
                      </td>

                      <td><StatusBadge status={p.status} /></td>
                      <td className="cell-muted">{new Date(p.requested_at || p.created_at).toLocaleDateString()}</td>
                      <td className="cell-muted">{p.paid_at ? new Date(p.paid_at).toLocaleDateString() : '—'}</td>

                      <td>
                        {p.status !== 'paid' && (
                          <div>
                            <button
                              className={`btn ${!isVerified ? 'btn-secondary' : 'btn-primary'} btn-xs`}
                              disabled={paying[p.id]}
                              onClick={() => setPayTarget(p)}
                              title={!isVerified ? 'Warning: Agent payout method name is not verified' : 'Mark as paid'}
                            >
                              {paying[p.id] ? '…' : 'Mark as Paid'}
                            </button>
                            {!isVerified && (
                              <div style={{ fontSize: 10, color: '#dc2626', marginTop: 2, fontWeight: 700 }}>
                                ⚠️ Blocked / Unverified
                              </div>
                            )}
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
      </div>

      {payTarget && (
        <ConfirmDialog
          title={payTarget.payout_method?.name_verified ? "Mark Payout as Paid?" : "⚠️ CAUTION: Unverified Payout Method"}
          description={
            payTarget.payout_method?.name_verified
              ? `Confirm payout of ₹${(payTarget.amount || 0).toLocaleString('en-IN')} to ${payTarget.profiles?.full_name || 'agent'}. This will mark the transfer as completed.`
              : `CAUTION: ${payTarget.profiles?.full_name || 'This agent'} has NOT verified their payout method name (Entered: "${payTarget.payout_method?.account_holder_name || 'None'}" vs Verified ID: "${payTarget.profiles?.full_name || 'None'}"). Release should typically be blocked until the name mismatch is resolved. Proceed anyway?`
          }
          confirmLabel={payTarget.payout_method?.name_verified ? "Mark as Paid" : "Force Mark as Paid"}
          confirmClass={payTarget.payout_method?.name_verified ? "btn btn-primary" : "btn btn-primary"}
          onConfirm={() => markPaid(payTarget)}
          onCancel={() => setPayTarget(null)}
        />
      )}
    </div>
  );
}
