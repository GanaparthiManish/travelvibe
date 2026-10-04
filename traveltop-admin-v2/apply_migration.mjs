import fs from 'fs';
import path from 'path';
import http from 'https';

const sqlPath = path.resolve('../migration_destination_gallery_and_reviews.sql');
const sqlContent = fs.readFileSync(sqlPath, 'utf8');

console.log('Sending migration SQL to Edge function bright-task...');

const payload = JSON.stringify({
  action: 'exec_sql',
  sql: sqlContent
});

const req = http.request('https://imretkikrsdydreldosx.supabase.co/functions/v1/bright-task', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw'
  }
}, (res) => {
  let body = '';
  res.on('data', chunk => body += chunk);
  res.on('end', () => console.log('Edge function response:', body));
});

req.on('error', (err) => {
  console.error('Request error:', err);
});

req.write(payload);
req.end();
