// create-payment-intent — Supabase Edge Function
//
// Creates a Stripe PaymentIntent for the tip jar and returns the client
// secret that the iOS app passes to Stripe's PaymentSheet.
//
// Setup:
//   1. Supabase -> Edge Functions -> "create-payment-intent" -> paste this
//      file -> Deploy.
//   2. Edge Functions -> create-payment-intent -> Secrets -> add:
//        STRIPE_SECRET_KEY      (sk_live_... — never ship this to the app)
//        STRIPE_PUBLISHABLE_KEY (pk_live_... — the app calls this endpoint;
//                                the publishable key itself lives in the app)
//   3. Call from the app:
//        POST https://<project-ref>.supabase.co/functions/v1/create-payment-intent
//        Authorization: Bearer <anon or user JWT>
//        Body: { "amount": 500, "currency": "chf" }   // amount in minor units
//
// Response: { "clientSecret": "pi_..." }

import Stripe from "npm:stripe@14";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2023-10-16",
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const amount = body?.amount;
    const currency = body?.currency || "chf";

    if (!Number.isInteger(amount) || amount <= 0) {
      return new Response(JSON.stringify({ error: "Invalid amount" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
    });

    return new Response(
      JSON.stringify({ clientSecret: paymentIntent.client_secret }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
