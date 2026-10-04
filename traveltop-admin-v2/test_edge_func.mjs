import http from 'https';

const payload = JSON.stringify({ action: 'exec_sql', sql: 'CREATE TABLE IF NOT EXISTS public.agent_addons (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), agent_id uuid, category text, name text, price_per_day numeric, description text, is_active boolean DEFAULT true);' });

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

req.write(payload);
req.end();
