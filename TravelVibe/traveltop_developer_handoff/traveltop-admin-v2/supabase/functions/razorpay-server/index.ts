// Supabase Edge Function for Razorpay Order Creation & HMAC Verification
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const RZP_KEY_ID = Deno.env.get("RAZORPAY_KEY_ID") || "rzp_test_TS17iNcFE9sLbo";
const RZP_KEY_SECRET = Deno.env.get("RAZORPAY_KEY_SECRET") || "dummy_secret";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://imretkikrsdydreldosx.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, amount, currency = "INR", receipt, notes, razorpay_order_id, razorpay_payment_id, razorpay_signature, booking_payload, order_payload } = body;

    // 1. ACTION: CREATE_ORDER
    if (action === "create_order") {
      const authHeader = "Basic " + btoa(`${RZP_KEY_ID}:${RZP_KEY_SECRET}`);
      const rzpRes = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader,
        },
        body: JSON.stringify({
          amount: Math.round(amount), // in paise
          currency,
          receipt: receipt || `rcpt_${Date.now()}`,
          notes: notes || {},
        }),
      });

      const rzpData = await rzpRes.json();
      if (!rzpRes.ok) {
        return new Response(
          JSON.stringify({ success: false, error: rzpData.error?.description || "Failed to create Razorpay Order" }),
          { status: rzpRes.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      return new Response(
        JSON.stringify({ success: true, order: rzpData, razorpay_order_id: rzpData.id }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. ACTION: VERIFY_PAYMENT
    if (action === "verify_payment") {
      if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
        return new Response(
          JSON.stringify({ success: false, error: "Missing required payment verification parameters" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Compute HMAC SHA-256 signature
      const encoder = new TextEncoder();
      const keyData = encoder.encode(RZP_KEY_SECRET);
      const msgData = encoder.encode(`${razorpay_order_id}|${razorpay_payment_id}`);

      const cryptoKey = await crypto.subtle.importKey(
        "raw",
        keyData,
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
      );

      const signatureBuffer = await crypto.subtle.sign("HMAC", cryptoKey, msgData);
      const generatedSignature = Array.from(new Uint8Array(signatureBuffer))
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

      const isSignatureValid = generatedSignature === razorpay_signature;

      if (!isSignatureValid) {
        return new Response(
          JSON.stringify({ success: false, error: "HMAC Signature verification failed. Payment untrusted." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // ONLY on verification passing: Insert booking / order row server-side using service role
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

      let savedRecord = null;

      if (booking_payload) {
        const { data: bData, error: bErr } = await supabase
          .from("bookings")
          .insert({
            ...booking_payload,
            status: "confirmed",
            payment_id: razorpay_payment_id,
            admin_note: `Paid via Razorpay (${razorpay_payment_id})`,
          })
          .select()
          .single();

        if (bErr) throw bErr;
        savedRecord = bData;
      }

      if (order_payload) {
        const { data: oData, error: oErr } = await supabase
          .from("orders")
          .insert({
            ...order_payload,
            status: "placed",
            payment_status: `Paid (Razorpay: ${razorpay_payment_id})`,
            payment_id: razorpay_payment_id,
          })
          .select()
          .single();

        if (oErr) throw oErr;
        savedRecord = oData;
      }

      return new Response(
        JSON.stringify({ success: true, verified: true, payment_id: razorpay_payment_id, record: savedRecord }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. ACTION: SAVE_ORDER (Bypasses RLS using Service Role Key)
    if (action === "save_order") {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const { data, error } = await supabase
        .from("orders")
        .insert({
          traveller_id: order_payload.traveller_id,
          items: order_payload.items,
          total_amount: order_payload.total_amount,
          status: order_payload.status || "placed",
          delivery_address: order_payload.delivery_address,
        })
        .select();

      if (error) throw error;
      return new Response(
        JSON.stringify({ success: true, data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. ACTION: SAVE_BOOKING (Bypasses RLS using Service Role Key)
    if (action === "save_booking") {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
      const { data, error } = await supabase
        .from("bookings")
        .insert({
          traveller_id: booking_payload.traveller_id,
          agent_id: booking_payload.agent_id,
          destination: booking_payload.destination,
          start_date: booking_payload.start_date,
          end_date: booking_payload.end_date,
          total_price: booking_payload.total_price,
          status: booking_payload.status === "confirmed" ? "accepted" : (booking_payload.status || "accepted"),
          trip_notes: booking_payload.trip_notes,
        })
        .select();

      if (error) throw error;
      return new Response(
        JSON.stringify({ success: true, data }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: false, error: "Invalid action" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
