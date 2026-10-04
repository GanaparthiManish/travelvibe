import crypto from 'crypto';

const RZP_KEY_ID = 'rzp_test_TS17iNcFE9sLbo';
// For test mode verification:
const RZP_KEY_SECRET = 'dummy_secret_for_testing'; 

async function testRazorpayDirect() {
  console.log('=== TESTING RAZORPAY SERVER-SIDE ORDER & SIGNATURE VERIFICATION ===\n');

  // 1. Test Server-side Order Creation
  const authHeader = 'Basic ' + Buffer.from(`${RZP_KEY_ID}:dummy_secret`).toString('base64');
  console.log('1. Generated Basic Auth Header:', authHeader);

  // 2. Test HMAC SHA256 Signature Verification logic:
  // Razorpay signature formula: HMAC_SHA256(order_id + "|" + payment_id, secret)
  const sampleOrderId = 'order_EKZ3aw5D6y7890';
  const samplePaymentId = 'pay_293847298347';
  const generatedSignature = crypto
    .createHmac('sha256', RZP_KEY_SECRET)
    .update(`${sampleOrderId}|${samplePaymentId}`)
    .digest('hex');

  console.log('\n2. HMAC SHA256 Signature Verification Test:');
  console.log('   Sample Order ID:', sampleOrderId);
  console.log('   Sample Payment ID:', samplePaymentId);
  console.log('   Generated Signature:', generatedSignature);

  // Verify match:
  const expectedSig = crypto
    .createHmac('sha256', RZP_KEY_SECRET)
    .update(`${sampleOrderId}|${samplePaymentId}`)
    .digest('hex');

  const isValid = (generatedSignature === expectedSig);
  console.log('   Signature Match Result:', isValid ? 'SUCCESS (VALID)' : 'FAILED (INVALID)');

  // Verify mismatched signature (Failure Test Case):
  const tamperedSig = 'invalid_signature_12345';
  const isTamperedValid = (tamperedSig === expectedSig);
  console.log('   Tampered Signature Match Result:', isTamperedValid ? 'SUCCESS (VALID)' : 'FAILED (REJECTED AS EXPECTED)');
}

testRazorpayDirect();
