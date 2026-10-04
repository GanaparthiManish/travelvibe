async function testImageUrl() {
  const url = 'https://imretkikrsdydreldosx.supabase.co/storage/v1/object/public/verification-docs/cdc23bc0-6b3c-4017-b3c5-38b37099bd23/1787149064928_IMG_20260815_164826985.jpg';
  const res = await fetch(url);
  console.log('Status for URL:', res.status, res.statusText);
  console.log('Content Type:', res.headers.get('content-type'));
}
testImageUrl();
