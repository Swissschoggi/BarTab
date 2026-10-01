// price-alert — Supabase Edge Function
//
// Triggered by a Database Webhook on the `prices` table (INSERT event).
// It looks up every active price alert matching the new price, finds the
// owners' APNS device tokens, and sends them a push notification.
//
// Setup (Supabase web dashboard):
//   1. Edge Functions -> New function -> name it "price-alert" -> paste
//      this file -> Deploy.
//   2. Edge Functions -> price-alert -> Secrets -> add:
//        APNS_KEY_ID       (your .p8 Key ID)
//        APNS_TEAM_ID      (your 10-char Apple Team ID)
//        APNS_PRIVATE_KEY  (the full .p8 contents, including the BEGIN/END lines)
//        APNS_BUNDLE_ID    (e.g. com.bartap.app)
//   3. Database -> Webhooks -> Create webhook:
//        Table: prices
//        Events: INSERT
//        URL: https://<project-ref>.supabase.co/functions/v1/price-alert
//      (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically.)

const encoder = new TextEncoder();

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function base64URL(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importAPNSKey(pem: string): Promise<CryptoKey> {
  const key = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const raw = Uint8Array.from(atob(key), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    raw.buffer as ArrayBuffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

async function signJWT(key: CryptoKey, teamID: string, keyID: string): Promise<string> {
  const header = { alg: "ES256", kid: keyID };
  const payload = { iss: teamID, iat: Math.floor(Date.now() / 1000) };
  const headerB64 = base64URL(encoder.encode(JSON.stringify(header)).buffer as ArrayBuffer);
  const payloadB64 = base64URL(encoder.encode(JSON.stringify(payload)).buffer as ArrayBuffer);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(`${headerB64}.${payloadB64}`).buffer as ArrayBuffer,
  );
  return `${headerB64}.${payloadB64}.${base64URL(signature)}`;
}

async function sendOne(token: string, jwt: string, title: string, body: string, deepLink?: string) {
  const apnsTopic = Deno.env.get("APNS_BUNDLE_ID") ?? "com.bartap.app";
  const aps: Record<string, unknown> = { alert: { title, body }, sound: "default" };
  const payload: Record<string, unknown> = { aps };
  if (deepLink) payload["deep_link"] = deepLink;

  const res = await fetch(`https://api.push.apple.com/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": apnsTopic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error(`APNS ${res.status}: ${await res.text()}`);
}

// PostgREST query helper using the service-role key (bypasses RLS).
async function supabaseQuery(path: string): Promise<any> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: {
      apikey: SERVICE_ROLE_KEY,
      authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
  });
  if (!res.ok) throw new Error(`PostgREST ${res.status}: ${await res.text()}`);
  return res.json();
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  try {
    const { record } = await req.json();
    if (!record || !record.bar_id || !record.drink || !record.size) {
      return new Response(JSON.stringify({ skipped: "missing fields" }), {
        headers: { "content-type": "application/json" },
      });
    }

    const amount = Number(record.amount);

    // 1. Find matching active alerts for this bar + drink + size.
    const alerts = await supabaseQuery(
      `price_alerts?bar_id=eq.${record.bar_id}&drink=eq.${encodeURIComponent(record.drink)}` +
        `&size=eq.${encodeURIComponent(record.size)}&is_active=eq.true&select=*`,
    );

    // 2. Filter by brand (an alert with no brand matches any brand) and
    //    by target price (alert fires when the price is at or below target).
    const matching = alerts.filter((a: any) => {
      const brandMatches = a.brand == null || a.brand === (record.brand ?? null);
      const target = a.target_price == null ? null : Number(a.target_price);
      const priceMatches = target == null || amount <= target;
      return brandMatches && priceMatches;
    });

    if (matching.length === 0) {
      return new Response(JSON.stringify({ skipped: "no matching alerts" }), {
        headers: { "content-type": "application/json" },
      });
    }

    // 3. Collect the alert owners (deduplicated).
    const userIDs = [...new Set(matching.map((a: any) => a.user_id))];
    const idList = userIDs.join(",");

    const profiles = await supabaseQuery(
      `profiles?id=in.(${idList})&select=id,apns_device_token`,
    );
    const tokens = profiles
      .map((p: any) => p.apns_device_token)
      .filter((t: string | null | undefined) => t && t.length > 0) as string[];

    if (tokens.length === 0) {
      return new Response(JSON.stringify({ skipped: "no device tokens" }), {
        headers: { "content-type": "application/json" },
      });
    }

    // 4. Bar name for the notification body.
    let barName = "A bar you follow";
    try {
      const bars = await supabaseQuery(`bars?id=eq.${record.bar_id}&select=name`);
      if (bars[0]?.name) barName = bars[0].name;
    } catch {
      // Non-fatal: fall back to the generic label.
    }

    // 5. Sign JWT once and send to every token.
    const keyID = Deno.env.get("APNS_KEY_ID");
    const teamID = Deno.env.get("APNS_TEAM_ID");
    const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
    if (!keyID || !teamID || !privateKey) {
      return new Response(JSON.stringify({ error: "APNS secrets not configured" }), { status: 500 });
    }

    const key = await importAPNSKey(privateKey);
    const jwt = await signJWT(key, teamID, keyID);

    const title = "Price alert";
    const body = `${barName}  ${record.amount} ${record.currency}`;
    const deepLink = `bartab://bar/${record.bar_id}`;

    const results = await Promise.allSettled(
      tokens.map((t) => sendOne(t, jwt, title, body, deepLink)),
    );

    const sent = results.filter((r) => r.status === "fulfilled").length;
    return new Response(JSON.stringify({ sent, total: tokens.length }), {
      headers: { "content-type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
