import React, { useRef, useState } from 'react';
import { supabase } from '../lib/supabase';

export default function ImageDropzone({ bucket, value, onChange, label = 'Cover Image', hint = 'PNG, JPG up to 5MB' }) {
  const inputRef = useRef();
  const [dragging, setDragging] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);

  async function upload(file) {
    if (!file) return;
    setUploading(true);
    setError(null);
    const ext = file.name.split('.').pop();
    const path = `${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
    const { error: upErr } = await supabase.storage.from(bucket).upload(path, file, { upsert: true });
    if (upErr) { setError(upErr.message); setUploading(false); return; }
    const { data } = supabase.storage.from(bucket).getPublicUrl(path);
    onChange(data.publicUrl);
    setUploading(false);
  }

  function handleDrop(e) {
    e.preventDefault();
    setDragging(false);
    const file = e.dataTransfer.files[0];
    if (file) upload(file);
  }

  return (
    <div className="field-group">
      <label className="field-label">{label}</label>
      <div
        className={`dropzone${dragging ? ' dragging' : ''}`}
        onClick={() => inputRef.current.click()}
        onDragOver={e => { e.preventDefault(); setDragging(true); }}
        onDragLeave={() => setDragging(false)}
        onDrop={handleDrop}
      >
        {value ? (
          <img src={value} alt="Preview" className="dropzone-preview" />
        ) : (
          <>
            <div className="dropzone-icon">📸</div>
            <div className="dropzone-text">{uploading ? 'Uploading…' : 'Click or drag to upload'}</div>
            <div className="dropzone-hint">{hint}</div>
          </>
        )}
        {uploading && <div className="dropzone-text" style={{ marginTop: 6, color: 'var(--accent)' }}>Uploading…</div>}
      </div>
      {value && (
        <button className="btn btn-ghost btn-sm" style={{ marginTop: 6 }} onClick={e => { e.stopPropagation(); onChange(''); }}>
          Remove image
        </button>
      )}
      {error && <div className="field-error">{error}</div>}
      <input ref={inputRef} type="file" accept="image/*" style={{ display: 'none' }}
        onChange={e => upload(e.target.files[0])} />
    </div>
  );
}

// Multi-image dropzone for place images
export function MultiImageDropzone({ bucket, images = [], onChange }) {
  const inputRef = useRef();
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState(null);

  async function upload(files) {
    setUploading(true);
    setError(null);
    const urls = [];
    for (const file of files) {
      const ext = file.name.split('.').pop();
      const path = `${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
      const { error: upErr } = await supabase.storage.from(bucket).upload(path, file, { upsert: true });
      if (upErr) { setError(upErr.message); continue; }
      const { data } = supabase.storage.from(bucket).getPublicUrl(path);
      urls.push(data.publicUrl);
    }
    onChange([...images, ...urls]);
    setUploading(false);
  }

  function removeImage(idx) {
    onChange(images.filter((_, i) => i !== idx));
  }

  return (
    <div>
      <div
        className="dropzone"
        onClick={() => inputRef.current.click()}
        onDragOver={e => e.preventDefault()}
        onDrop={e => { e.preventDefault(); upload(Array.from(e.dataTransfer.files)); }}
      >
        <div className="dropzone-icon">🖼️</div>
        <div className="dropzone-text">{uploading ? 'Uploading…' : 'Click or drag to add images'}</div>
        <div className="dropzone-hint">Add up to 10 images. First image is the cover.</div>
      </div>
      {images.length > 0 && (
        <div className="image-strip">
          {images.map((url, i) => (
            <div key={i} className="image-thumb">
              <img src={url} alt="" />
              <button className="image-thumb-remove" onClick={() => removeImage(i)}>✕</button>
            </div>
          ))}
        </div>
      )}
      {error && <div className="field-error">{error}</div>}
      <input ref={inputRef} type="file" accept="image/*" multiple style={{ display: 'none' }}
        onChange={e => upload(Array.from(e.target.files))} />
    </div>
  );
}
