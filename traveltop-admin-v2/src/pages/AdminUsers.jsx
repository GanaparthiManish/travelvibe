import React, { useEffect, useState, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import Skeleton from '../components/Skeleton';
import ErrorState from '../components/ErrorState';
import ConfirmDialog from '../components/ConfirmDialog';
import StatusBadge from '../components/StatusBadge';

const ROLES = ['super_admin', 'support_staff'];

function InviteModal({ onClose, onSaved }) {
  const { toast } = useToast();
  const [email, setEmail] = useState('');
  const [fullName, setFullName] = useState('');
  const [role, setRole] = useState('support_staff');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function invite() {
    if (!email.trim() || !fullName.trim()) {
      toast('Email and name are required', 'error');
      return;
    }
    setSaving(true);
    setError(null);

    // Invite user via Supabase Auth (sends invite email)
    const { data, error: inviteErr } = await supabase.auth.admin?.inviteUserByEmail?.(email);

    if (inviteErr) {
      // If admin API not available, just insert the record with the email
      // and they can sign up themselves
      setError('Note: Could not send invite email directly. The user must sign up at Supabase and then you can grant access below.');
    }

    // Insert into admin_users (using email as a lookup - they'll need to sign up first)
    // For now we do a best-effort approach: insert by creating a placeholder
    // In production, this would be done via a Supabase Edge Function with service role
    const userId = data?.user?.id;
    if (userId) {
      const { error: insertErr } = await supabase.from('admin_users')
        .insert({ id: userId, full_name: fullName, role });
      if (insertErr) { setError(insertErr.message); setSaving(false); return; }
      toast(`${fullName} invited as ${role.replace('_', ' ')}`, 'success');
      onSaved();
      onClose();
    } else {
      // Fallback: user needs to self-register first
      setError(`User must first create a Supabase account with ${email}, then you can add them below.`);
    }
    setSaving(false);
  }

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal modal-sm" style={{ marginTop: 'auto', marginBottom: 'auto' }}>
        <div className="modal-header">
          <div className="modal-title">Invite Admin User</div>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          {error && <div className="login-error" style={{ marginBottom: 12 }}>{error}</div>}
          <div className="field-group">
            <label className="field-label">Full Name *</label>
            <input className="field-input" value={fullName} onChange={e => setFullName(e.target.value)} placeholder="e.g. Ravi Kumar" />
          </div>
          <div className="field-group">
            <label className="field-label">Email Address *</label>
            <input className="field-input" type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="admin@traveltop.com" />
          </div>
          <div className="field-group">
            <label className="field-label">Role</label>
            <select className="field-input" value={role} onChange={e => setRole(e.target.value)}>
              {ROLES.map(r => <option key={r} value={r}>{r.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase())}</option>)}
            </select>
            <div className="field-hint">
              <strong>Super Admin</strong> — full access including admin management<br />
              <strong>Support Staff</strong> — Bookings, Users, Reviews only; no delete/suspend
            </div>
          </div>
        </div>
        <div className="modal-footer">
          <button className="btn btn-ghost" onClick={onClose}>Cancel</button>
          <button className="btn btn-primary" onClick={invite} disabled={saving}>{saving ? 'Inviting…' : 'Send Invite'}</button>
        </div>
      </div>
    </div>
  );
}

export default function AdminUsers() {
  const { toast } = useToast();
  const { adminUser: me, isSuperAdmin } = useAuth();
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showInvite, setShowInvite] = useState(false);
  const [removeTarget, setRemoveTarget] = useState(null);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error: err } = await supabase
        .from('admin_users')
        .select('*')
        .order('created_at', { ascending: false });
      if (err) throw err;
      setRows(data || []);
      setError(null);
    } catch (e) { setError(e.message); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  async function removeAccess() {
    await supabase.from('admin_users').delete().eq('id', removeTarget.id);
    toast(`${removeTarget.full_name}'s admin access removed`, 'success');
    setRemoveTarget(null);
    fetchData();
  }

  async function changeRole(user, newRole) {
    await supabase.from('admin_users').update({ role: newRole }).eq('id', user.id);
    setRows(rows.map(r => r.id === user.id ? { ...r, role: newRole } : r));
    toast('Role updated', 'success');
  }

  if (!isSuperAdmin) {
    return (
      <div className="error-state">
        <div className="error-state-icon">🔒</div>
        <div className="error-state-title">Access Restricted</div>
        <div className="error-state-desc">Only Super Admins can manage admin users.</div>
      </div>
    );
  }

  return (
    <div>
      <div className="card">
        <div className="card-header">
          <div>
            <div className="card-title">Admin Users</div>
            <div className="card-meta">{rows.length} admin account{rows.length !== 1 ? 's' : ''}</div>
          </div>
          <button className="btn btn-primary btn-sm" onClick={() => setShowInvite(true)}>+ Invite Admin</button>
        </div>

        <div className="table-wrap">
          <table>
            <thead><tr>
              <th>Name</th>
              <th>Role</th>
              <th>Added</th>
              <th>Actions</th>
            </tr></thead>
            <tbody>
              {loading ? <tr><td colSpan={4}><Skeleton rows={4} cols={4} /></td></tr>
                : error ? <tr><td colSpan={4}><ErrorState message={error} onRetry={fetchData} /></td></tr>
                : rows.length === 0 ? (
                  <tr><td colSpan={4}>
                    <div className="empty-state">
                      <div className="empty-state-icon">🔑</div>
                      <div className="empty-state-title">No admin users found</div>
                    </div>
                  </td></tr>
                ) : rows.map(u => (
                  <tr key={u.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div className="avatar-fallback" style={{ width: 34, height: 34 }}>
                          {(u.full_name || 'A')[0]}
                        </div>
                        <div>
                          <div style={{ fontWeight: 600 }}>{u.full_name || '—'}</div>
                          {u.id === me?.id && <span className="badge badge-blue" style={{ fontSize: 10 }}>You</span>}
                        </div>
                      </div>
                    </td>
                    <td>
                      {u.id === me?.id ? (
                        <span className={`badge ${u.role === 'super_admin' ? 'badge-purple' : 'badge-blue'}`}>
                          {u.role?.replace('_', ' ')}
                        </span>
                      ) : (
                        <select
                          className="field-input"
                          style={{ width: 160, padding: '4px 8px', fontSize: 12 }}
                          value={u.role}
                          onChange={e => changeRole(u, e.target.value)}
                        >
                          {ROLES.map(r => (
                            <option key={r} value={r}>{r.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase())}</option>
                          ))}
                        </select>
                      )}
                    </td>
                    <td className="cell-muted">{u.created_at ? new Date(u.created_at).toLocaleDateString() : '—'}</td>
                    <td>
                      {u.id !== me?.id && (
                        <button className="btn btn-danger-text btn-xs" onClick={() => setRemoveTarget(u)}>
                          Remove Access
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              }
            </tbody>
          </table>
        </div>
      </div>

      {showInvite && <InviteModal onClose={() => setShowInvite(false)} onSaved={fetchData} />}

      {removeTarget && (
        <ConfirmDialog
          title="Remove Admin Access?"
          description={`${removeTarget.full_name} will lose all admin access immediately. They will not be able to log in to this console.`}
          confirmLabel="Remove Access"
          confirmClass="btn btn-primary"
          onConfirm={removeAccess}
          onCancel={() => setRemoveTarget(null)}
        />
      )}
    </div>
  );
}
