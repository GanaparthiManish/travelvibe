import React from 'react';

const STATUS_MAP = {
  // Bookings
  confirmed: { cls: 'badge-green', label: 'Confirmed' },
  confirmed_cod: { cls: 'badge-amber', label: 'Confirmed (COD)' },
  pending: { cls: 'badge-amber', label: 'Pending' },
  pending_cod: { cls: 'badge-amber', label: 'Pending (COD)' },
  cancelled: { cls: 'badge-red', label: 'Cancelled' },
  completed: { cls: 'badge-blue', label: 'Completed' },
  ongoing: { cls: 'badge-blue', label: 'Ongoing' },
  // Agents
  approved: { cls: 'badge-green', label: 'Approved' },
  rejected: { cls: 'badge-red', label: 'Rejected' },
  suspended: { cls: 'badge-red', label: 'Suspended' },
  under_review: { cls: 'badge-amber', label: 'Under Review' },
  // Payments / payouts
  paid: { cls: 'badge-green', label: 'Paid' },
  requested: { cls: 'badge-amber', label: 'Requested' },
  failed: { cls: 'badge-red', label: 'Failed' },
  // Orders
  placed: { cls: 'badge-blue', label: 'Placed' },
  packed: { cls: 'badge-purple', label: 'Packed' },
  shipped: { cls: 'badge-purple', label: 'Shipped' },
  out_for_delivery: { cls: 'badge-amber', label: 'Out for Delivery' },
  delivered: { cls: 'badge-green', label: 'Delivered' },
  // Boolean / generic
  active: { cls: 'badge-green', label: 'Active' },
  inactive: { cls: 'badge-gray', label: 'Inactive' },
  true: { cls: 'badge-green', label: 'Yes' },
  false: { cls: 'badge-gray', label: 'No' },
  verified: { cls: 'badge-green', label: 'Verified' },
};


export default function StatusBadge({ status, label }) {
  const key = String(status).toLowerCase().replace(/\s+/g, '_');
  const cfg = STATUS_MAP[key] || { cls: 'badge-gray', label: label || status };
  return (
    <span className={`badge ${cfg.cls}`}>
      <span className="badge-dot" />
      {label || cfg.label}
    </span>
  );
}
