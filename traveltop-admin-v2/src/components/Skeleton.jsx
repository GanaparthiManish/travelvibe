import React from 'react';

export default function Skeleton({ rows = 5, cols = 4 }) {
  return (
    <div>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px', borderBottom: '1px solid #EBEBEB' }}>
          {Array.from({ length: cols }).map((_, j) => (
            <div key={j} className={`skeleton skeleton-text`} style={{ height: 12, flex: j === 0 ? '0 0 34px' : 1, borderRadius: 6 }} />
          ))}
        </div>
      ))}
    </div>
  );
}

export function SkeletonCard() {
  return (
    <div style={{ padding: 20, display: 'flex', flexDirection: 'column', gap: 10 }}>
      <div className="skeleton skeleton-text" style={{ width: '40%', height: 14 }} />
      <div className="skeleton skeleton-text" style={{ width: '60%', height: 12 }} />
      <div className="skeleton skeleton-text" style={{ width: '30%', height: 12 }} />
    </div>
  );
}
