import React from 'react';

export default function ErrorState({ message = 'Something went wrong', onRetry }) {
  return (
    <div className="error-state">
      <div className="error-state-icon">⚠️</div>
      <div className="error-state-title">Failed to load</div>
      <div className="error-state-desc">{message}</div>
      {onRetry && (
        <button className="btn btn-secondary" style={{ marginTop: 8 }} onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  );
}
