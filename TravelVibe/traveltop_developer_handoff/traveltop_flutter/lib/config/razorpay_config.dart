class RazorpayConfig {
  /// Replace this with your Live Razorpay Key ID from the Razorpay Dashboard (e.g. 'rzp_live_XXXXXXXXXXXXXX')
  static String razorpayKeyId = 'rzp_live_TTL2sXnnFpbg5i';

  /// Check if the app is currently running in Live / Realtime Production mode
  static bool get isLiveMode => razorpayKeyId.startsWith('rzp_live_');
}
