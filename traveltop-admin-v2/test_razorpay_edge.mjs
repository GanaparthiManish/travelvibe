const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

async function testEdgeOrder() {
  console.log('--- Testing Edge Function create_order ---');
  const res = await fetch('https://imretkikrsdydreldosx.supabase.co/functions/v1/bright-task', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
    },
    body: JSON.stringify({
      action: 'create_order',
      amount: 50000, // 500 INR in paise
      currency: 'INR',
      receipt: `rcpt_test_${Date.now()}`
    })
  });

  const data = await res.json();
  console.log('Edge Function Response Status:', res.status);
  console.log('Edge Function Response Data:', data);
}

testEdgeOrder();
