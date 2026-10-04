import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import Pagination from '../components/Pagination';
import StatusBadge from '../components/StatusBadge';

const PAGE_SIZE = 20;
const ORDER_STATUSES = ['placed', 'packed', 'shipped', 'out_for_delivery', 'delivered'];

export default function Orders() {
  const { toast } = useToast();
  const [rows, setRows] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [updating, setUpdating] = useState({});
  const [selectedOrder, setSelectedOrder] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      let dbOrders = [];
      try {
        let q = supabase.from('orders').select('*', { count: 'exact' });
        q = q.order('created_at', { ascending: false });
        const { data, error: oErr } = await q;
        if (oErr) throw oErr;
        if (data) dbOrders = data;
      } catch (err) {
        console.warn('DB Orders query error:', err.message);
      }

      const allOrders = [...dbOrders];

      // Try fetching profiles for traveller_ids
      const userIds = [...new Set(allOrders.map(o => o.traveller_id).filter(Boolean))];
      let profilesMap = {};
      if (userIds.length > 0) {
        try {
          const { data: pData } = await supabase.from('profiles').select('id, full_name, email').in('id', userIds);
          if (pData) {
            pData.forEach(p => { profilesMap[p.id] = p; });
          }
        } catch (_) {}
      }

      let filtered = allOrders;
      if (search.trim()) {
        const s = search.toLowerCase();
        filtered = allOrders.filter(o =>
          (o.id || '').toLowerCase().includes(s) ||
          (o.traveller_name || '').toLowerCase().includes(s) ||
          (o.traveller_email || '').toLowerCase().includes(s) ||
          (o.traveller_id || '').toLowerCase().includes(s) ||
          (o.delivery_address?.phone || '').includes(s) ||
          (o.delivery_address?.line1 || '').toLowerCase().includes(s)
        );
      }

      const parseAddress = (addr) => {
        if (!addr) return {};
        if (typeof addr === 'object') return addr;
        if (typeof addr === 'string') {
          try {
            const parsed = JSON.parse(addr);
            if (typeof parsed === 'object' && parsed !== null) return parsed;
          } catch (_) {}
          return { line1: addr };
        }
        return {};
      };

      const formatted = filtered.map(o => {
        const addrObj = parseAddress(o.delivery_address);
        const p = profilesMap[o.traveller_id];
        const email = o.traveller_email || addrObj.email || p?.email || (typeof o.delivery_address === 'object' ? o.delivery_address?.email : null) || '—';
        const name = o.traveller_name || addrObj.name || p?.full_name || (email !== '—' ? email.split('@')[0] : 'Traveller');
        
        // Accurately detect Cash on Delivery vs Online UPI/Razorpay
        const rawMethod = (addrObj.payment_method || o.payment_method || (o.items?.[0]?.payment_method) || '').toString().toLowerCase();
        const isCod = rawMethod.includes('cod') || rawMethod.includes('cash');
        const displayPaymentMethod = isCod ? 'Cash on Delivery (COD)' : (rawMethod.includes('razor') || rawMethod.includes('upi') ? 'Razorpay UPI' : (o.payment_method ? o.payment_method.toUpperCase() : 'Razorpay UPI'));
        const displayPaymentStatus = isCod ? 'Pending (COD)' : (o.payment_status === 'paid' ? 'Paid' : (o.payment_status || 'Paid'));

        return {
          ...o,
          parsed_address: addrObj,
          profiles: {
            full_name: name,
            email: email
          },
          display_payment_method: displayPaymentMethod,
          display_payment_status: displayPaymentStatus
        };
      });

      const startIdx = (page - 1) * PAGE_SIZE;
      const paginated = formatted.slice(startIdx, startIdx + PAGE_SIZE);

      setRows(paginated);
      setTotal(formatted.length);
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => {
    fetchData();

    // 1. Postgres changes listener on orders table
    const chOrders = supabase.channel('admin-orders-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, (p) => {
        console.log('Orders DB update received:', p);
        fetchData();
      })
      .subscribe((status) => {
        console.log('Orders subscription status:', status);
      });

    // 2. Realtime broadcast listener for instant new orders from mobile & web apps
    const broadcastCh = supabase.channel('order_live_status_channel')
      .on('broadcast', { event: 'order_placed' }, (payload) => {
        console.log('Order Broadcast update received:', payload);
        const incoming = payload?.payload || payload?.data || payload;
        if (incoming?.id) {
          toast(`🆕 New Order #${incoming.id} received!`, 'success');
        }
        fetchData();
      })
      .subscribe((status) => {
        console.log('Order Broadcast subscription status:', status);
      });

    // 3. Global admin sync channel
    const globalSyncCh = supabase.channel('orders_global_admin_sync')
      .on('broadcast', { event: 'order_placed' }, () => {
        fetchData();
      })
      .subscribe();

    // 4. Heartbeat polling every 3 seconds + visibilitychange listener
    const poll = setInterval(() => fetchData(), 3000);
    const onVis = () => { if (document.visibilityState === 'visible') fetchData(); };
    document.addEventListener('visibilitychange', onVis);

    return () => {
      clearInterval(poll);
      document.removeEventListener('visibilitychange', onVis);
      supabase.removeChannel(chOrders);
      supabase.removeChannel(broadcastCh);
      supabase.removeChannel(globalSyncCh);
    };
  }, [fetchData, toast]);

  async function updateStatus(orderId, status) {
    setUpdating(prev => ({ ...prev, [orderId]: true }));

    // 1. Update in-memory state
    const nextRows = rows.map(r => r.id === orderId ? { ...r, status } : r);
    setRows(nextRows);

    // Update database orders table directly
    try {
      const { error } = await supabase.from('orders').update({ status }).eq('id', orderId);
      if (error) console.error('Error updating order status:', error);
    } catch (e) {
      console.error('Error updating order status:', e);
    }

    // 4. Send Realtime Broadcast to notify traveller mobile app
    try {
      const orderObj = rows.find(r => r.id === orderId);
      const buyerId = orderObj?.traveller_id || orderObj?.traveller_email;
      await supabase.channel('order_live_status_channel').send({
        type: 'broadcast',
        event: 'status_updated',
        payload: { order_id: orderId, status, user_id: buyerId },
      });
    } catch (_) {}

    toast(`Order #${orderId} status updated to "${status}"`, 'success');
    setUpdating(prev => ({ ...prev, [orderId]: false }));
  }

  function summarizeItems(items) {
    if (!items) return '—';
    try {
      const parsed = typeof items === 'string' ? JSON.parse(items) : items;
      if (Array.isArray(parsed)) return parsed.map(i => i.name || i.product_name || 'Item').slice(0, 2).join(', ') + (parsed.length > 2 ? ` +${parsed.length - 2}` : '');
      return JSON.stringify(items).slice(0, 50);
    } catch { return String(items).slice(0, 50); }
  }

  return (
    <div>
      <div className="card">
        <div className="table-controls">
          <div className="search-wrap">
            <span className="search-icon">🔍</span>
            <input className="search-input" placeholder="Search by order ID or traveller…" value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }} />
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead><tr><th>Traveller</th><th>Items</th><th>Payment</th><th>Total</th><th>Date</th><th>Status</th><th>Update Status</th></tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={7}><Skeleton rows={8} cols={7} /></td></tr>
                : error ? <tr><td colSpan={7}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={7}><div className="empty-state"><div className="empty-state-icon">📦</div><div className="empty-state-title">No orders yet</div></div></td></tr>
                ) : rows.map(o => (
                  <tr key={o.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedOrder(o)}>
                    <td>
                      <div style={{ fontWeight: 600 }}>{o.profiles?.full_name || o.traveller_name || o.parsed_address?.name || 'Traveller'}</div>
                      <div className="cell-muted">{o.profiles?.email || o.traveller_email || o.parsed_address?.email || '—'}</div>
                    </td>
                    <td className="cell-muted" style={{ maxWidth: 180 }}>{summarizeItems(o.items)}</td>
                    <td>
                      <span className="badge" style={{ background: o.display_payment_method?.includes('COD') ? '#fef3c7' : '#e0f2fe', color: o.display_payment_method?.includes('COD') ? '#d97706' : '#0369a1', fontWeight: 600, fontSize: 11 }}>
                        {o.display_payment_method?.includes('UPI') ? 'UPI' : (o.display_payment_method?.includes('Card') ? 'CARD' : (o.display_payment_method?.includes('Net') ? 'NET BANKING' : (o.display_payment_method?.includes('COD') ? 'COD' : 'UPI')))}
                      </span>
                    </td>
                    <td style={{ fontWeight: 600 }}>₹{(o.total_amount || o.total || 0).toLocaleString('en-IN')}</td>
                    <td className="cell-muted">{o.created_at ? new Date(o.created_at).toLocaleDateString() : '—'}</td>
                    <td><StatusBadge status={o.status} /></td>
                    <td onClick={e => e.stopPropagation()}>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <select
                          className="field-input"
                          style={{ width: 140, padding: '5px 8px', fontSize: 12 }}
                          value={o.status}
                          disabled={updating[o.id] || o.status === 'delivered'}
                          onChange={e => updateStatus(o.id, e.target.value)}
                        >
                          {ORDER_STATUSES.map(s => (
                            <option key={s} value={s}>{s.replace(/_/g, ' ')}</option>
                          ))}
                        </select>
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

      {selectedOrder && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 20
        }} onClick={e => { if (e.target === e.currentTarget) setSelectedOrder(null); }}>
          <div style={{
            background: '#ffffff', borderRadius: 16, width: '100%', maxWidth: 540,
            maxHeight: '90vh', overflowY: 'auto', padding: 24, boxShadow: '0 20px 25px -5px rgba(0,0,0,0.2)'
          }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20, borderBottom: '1px solid #f1f5f9', paddingBottom: 12 }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 800 }}>Order #{selectedOrder.id}</h3>
                <div style={{ fontSize: 12, color: '#64748b', marginTop: 2 }}>{selectedOrder.created_at ? new Date(selectedOrder.created_at).toLocaleString() : '—'}</div>
              </div>
              <button
                onClick={() => setSelectedOrder(null)}
                style={{ border: 'none', background: '#f1f5f9', borderRadius: '50%', width: 32, height: 32, cursor: 'pointer', fontSize: 16 }}
              >✕</button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div style={{ background: '#f8fafc', padding: 14, borderRadius: 12, border: '1px solid #e2e8f0' }}>
                <h4 style={{ margin: '0 0 8px 0', fontSize: 13, textTransform: 'uppercase', color: '#64748b' }}>📍 Delivery Address</h4>
                <div style={{ fontWeight: 600, fontSize: 14 }}>{selectedOrder.profiles?.full_name || selectedOrder.parsed_address?.name || selectedOrder.traveller_name || 'Traveller'}</div>
                <div style={{ fontSize: 13, color: '#334155', marginTop: 4 }}>
                  {selectedOrder.parsed_address?.line1 || (typeof selectedOrder.delivery_address === 'string' ? selectedOrder.delivery_address : '—')}
                  {selectedOrder.parsed_address?.line2 ? `, ${selectedOrder.parsed_address.line2}` : ''}
                </div>
                <div style={{ fontSize: 13, color: '#334155' }}>
                  {[selectedOrder.parsed_address?.city, selectedOrder.parsed_address?.pincode].filter(Boolean).join(', ')}
                </div>
                <div style={{ fontSize: 13, color: '#334155', marginTop: 4 }}>📞 Phone: {selectedOrder.parsed_address?.phone || selectedOrder.profiles?.phone || '—'}</div>
              </div>

              <div style={{ background: '#f8fafc', padding: 14, borderRadius: 12, border: '1px solid #e2e8f0' }}>
                <h4 style={{ margin: '0 0 8px 0', fontSize: 13, textTransform: 'uppercase', color: '#64748b' }}>💳 Payment Info</h4>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span className="badge" style={{
                      background: selectedOrder.display_payment_method?.includes('COD') ? '#fef3c7' : '#e0f2fe',
                      color: selectedOrder.display_payment_method?.includes('COD') ? '#d97706' : '#0369a1',
                      fontWeight: 700,
                      padding: '4px 10px',
                      borderRadius: 8,
                      fontSize: 12
                    }}>
                      {selectedOrder.display_payment_method || 'Cash on Delivery (COD)'}
                    </span>
                    <span style={{
                      fontSize: 13,
                      color: (selectedOrder.display_payment_status?.includes('Pending') || selectedOrder.payment_status === null) ? '#d97706' : '#059669',
                      fontWeight: 700
                    }}>
                      {selectedOrder.display_payment_status || (selectedOrder.display_payment_method?.includes('COD') ? 'Pending (COD)' : 'Paid')}
                    </span>
                  </div>
                  <div style={{ fontSize: 16, fontWeight: 800, color: '#0f172a' }}>
                    Total: ₹{(selectedOrder.total_amount || selectedOrder.total || 0).toLocaleString('en-IN')}
                  </div>
                </div>
              </div>

              <div style={{ background: '#f8fafc', padding: 14, borderRadius: 12, border: '1px solid #e2e8f0' }}>
                <h4 style={{ margin: '0 0 12px 0', fontSize: 13, textTransform: 'uppercase', color: '#64748b' }}>🛒 Purchased Items</h4>
                {Array.isArray(selectedOrder.items) && selectedOrder.items.map((item, i) => (
                  <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: i < selectedOrder.items.length - 1 ? 10 : 0 }}>
                    {item.image_url && <img src={item.image_url} alt={item.name} style={{ width: 44, height: 44, borderRadius: 8, objectFit: 'cover' }} />}
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 600, fontSize: 13.5 }}>{item.name || item.product_name}</div>
                      <div style={{ fontSize: 12, color: '#64748b' }}>Qty: {item.qty || item.quantity || 1} × ₹{(item.price || 0).toLocaleString('en-IN')}</div>
                    </div>
                    <div style={{ fontWeight: 700, fontSize: 13.5 }}>₹{((item.qty || 1) * (item.price || 0)).toLocaleString('en-IN')}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
