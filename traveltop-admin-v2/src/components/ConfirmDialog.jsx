import React from 'react';

export default function ConfirmDialog({ title, description, confirmLabel = 'Confirm', confirmClass = 'btn btn-primary', onConfirm, onCancel, children }) {
  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onCancel()}>
      <div className="modal modal-sm" style={{ marginTop: 'auto', marginBottom: 'auto' }}>
        <div className="confirm-dialog">
          <div className="confirm-icon">⚠️</div>
          <div className="confirm-title">{title}</div>
          <div className="confirm-desc">{description}</div>
          {children}
          <div className="confirm-actions">
            <button className="btn btn-secondary" onClick={onCancel}>Cancel</button>
            <button className={confirmClass} onClick={onConfirm}>{confirmLabel}</button>
          </div>
        </div>
      </div>
    </div>
  );
}
