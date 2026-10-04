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
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [payTarget, setPayTarget] = useState(null);
  const [paying, setPaying] = useState({});

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      let q = supabase.from('payouts')
        .select(`*, agent_details!agent_id(profiles(full_name))`, { count: 'exact' });
      if (statusFilter !== 'all') q = q.eq('status', statusFilter);
      q = q.order('requested_at', { ascending: false }).range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
      const { data, count, error: err } = await q;
      if (err) throw err;
      setRows(data || []); setTotal(count || 0); setError(null);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  }, [page, statusFilter, search]);

  useEffect(() => { fetchData(); }, [fetchData]);

  useEffect(() => {
    const ch = supabase.channel('payouts_rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'payouts' }, fetchData)
      .subscribe();
    return () => supabase.removeChannel(ch);
  }, [fetchData]);

  async function markPaid(payout) {
    setPaying(prev => ({ ...prev, [payout.id]: true }));
    await supabase.from('payouts').update({ status: 'paid', paid_at: new Date().toISOString() }).eq('id', payout.id);
    toast(`Payout of ₹${(payout.amount || 0).toLocaleString('en-IN')} marked as paid`, 'success');
    setPayTarget(null);
    setPaying(prev => ({ ...prev, [payout.id]: false }));
    fetchData();
  }

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search agents…" value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {['all', 'requested', 'paid'].map(s => (
              <button key={s} className={`filter-chip${statusFilter === s ? ' active' : ''}`}
                onClick={() => { setStatusFilter(s); setPage(1); }}>
                {s.charAt(0).toUpperCase() + s.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="table-wrap">
          <table>
            <thead><tr><th>Agent</th><th>Amount</th><th>Status</th><th>Requested</th><th>Paid At</th><th>Actions</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={6}><Skeleton rows={6} cols={6} /></td></tr>
                : error ? <tr><td colSpan={6}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={6}><div className="empty-state"><div className="empty-state-icon">💸</div><div className="empty-state-title">No payout requests</div></div></td></tr>
                ) : rows.map(p => (
                  <tr key={p.id}>
                    <td style={{ fontWeight: 600 }}>{p.agent_details?.profiles?.full_name || '—'}</td>
                    <td style={{ fontWeight: 700, fontSize: 14 }}>₹{(p.amount || 0).toLocaleString('en-IN')}</td>
                    <td><StatusBadge status={p.status} /></td>
                    <td className="cell-muted">{new Date(p.requested_at).toLocaleDateString()}</td>
                    <td className="cell-muted">{p.paid_at ? new Date(p.paid_at).toLocaleDateString() : '—'}</td>
                    <td>
                      {p.status !== 'paid' && (
                        <button className="btn btn-primary btn-xs" disabled={paying[p.id]}
                          onClick={() => setPayTarget(p)}>
                          {paying[p.id] ? '…' : 'Mark as Paid'}
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
        <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={setPage} />
      </div>

      {payTarget && (
        <ConfirmDialog
          title="Mark Payout as Paid?"
          description={`Confirm payment of ₹${(payTarget.amount || 0).toLocaleString('en-IN')} to ${payTarget.agent_details?.profiles?.full_name}. This will update their earnings screen in the Agent app.`}
          confirmLabel="Mark as Paid"
          confirmClass="btn btn-primary"
          onConfirm={() => markPaid(payTarget)}
          onCancel={() => setPayTarget(null)}
        />
      )}
    </div>
  );
}
