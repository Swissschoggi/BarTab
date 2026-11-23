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

// Tip amounts are a fixed menu, not a free-form value. Keeping the
// allow-list server-side means a modified client cannot create a
// PaymentIntent for an arbitrary amount or an unsupported currency.
const ALLOWED_TIP_AMOUNTS: Record<string, readonly number[]> = {
  chf: [200, 500, 1000, 2000, 5000],
  eur: [200, 500, 1000, 2000, 5000],
  usd: [200, 500, 1000, 2000, 5000],
  gbp: [200, 500, 1000, 2000, 5000],
};

const DEFAULT_CURRENCY = "chf";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await req.json().catch(() => null);

    if (!body || typeof body !== "object") {
      return json({ error: "Invalid request body" }, 400);
    }

    const currency = typeof body.currency === "string"
      ? body.currency.trim().toLowerCase()
      : DEFAULT_CURRENCY;

    const allowedAmounts = ALLOWED_TIP_AMOUNTS[currency];
    if (!allowedAmounts) {
      return json({ error: "Unsupported currency" }, 400);
    }

    const amount = body.amount;
    if (!Number.isInteger(amount) || !allowedAmounts.includes(amount)) {
      return json({ error: "Invalid tip amount" }, 400);
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      automatic_payment_methods: { enabled: true },
      description: "Bartap tip",
      metadata: { source: "bartap-tip-jar" },
    });

    return json({ clientSecret: paymentIntent.client_secret });
  } catch (error) {
    console.error("create-payment-intent failed", error);
    return json({ error: "Could not create payment intent" }, 400);
  }
});
