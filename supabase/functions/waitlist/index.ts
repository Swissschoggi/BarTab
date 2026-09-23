// BarTab waitlist signup.
//
// Security model: the `waitlist` table has NO public read/write policies.
// This function is the only writer, using the service-role key. Every request
// must first pass a server-side Cloudflare Turnstile check, and per-IP rate
// limiting caps how many submissions one address can make.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TURNSTILE_SECRET = Deno.env.get("TURNSTILE_SECRET")!;

// Comma-separated list of origins allowed to call this endpoint. Browsers
// enforce CORS, so requests from any other origin won't be able to read the
// response (defense in depth on top of Turnstile).
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "https://bartap.info")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const TURNSTILE_VERIFY_URL =
  "https://challenges.cloudflare.com/turnstile/v0/siteverify";

// In-memory per-IP rate limit. Edge Functions are short-lived, so this is a
// best-effort layer on top of Turnstile, not a durable store.
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const attempts = new Map<string, number[]>();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "Content-Type, Authorization, apikey, x-client-info",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...extra },
  });
}

function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  const real = req.headers.get("x-real-ip");
  if (real) return real.trim();
  return "unknown";
}

function rateLimited(ip: string): boolean {
  const now = Date.now();
  const windowStart = now - RATE_LIMIT_WINDOW_MS;
  const hits = (attempts.get(ip) ?? []).filter((t) => t > windowStart);
  hits.push(now);
  attempts.set(ip, hits);
  return hits.length > RATE_LIMIT_MAX;
}

async function verifyTurnstile(token: string, ip: string): Promise<boolean> {
  const body = new URLSearchParams();
  body.append("secret", TURNSTILE_SECRET);
  body.append("response", token);
  body.append("remoteip", ip);

  const res = await fetch(TURNSTILE_VERIFY_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!res.ok) return false;
  const data = await res.json();
  return data.success === true;
}

async function insertEmail(email: string): Promise<boolean> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/waitlist`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "resolution=ignore-duplicates",
    },
    body: JSON.stringify({ email }),
  });

  return res.status === 201;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const cors = corsHeaders(origin);

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405, cors);
  }

  const ip = clientIp(req);

  if (rateLimited(ip)) {
    return json({ error: "Too many attempts. Please try again later." }, 429, cors);
  }

  let email: string | undefined;
  let token: string | undefined;
  try {
    const payload = await req.json();
    email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";
    token = typeof payload.token === "string" ? payload.token : "";
  } catch {
    return json({ error: "Invalid request body." }, 400, cors);
  }

  if (!email || !EMAIL_RE.test(email) || email.length > 254) {
    return json({ error: "Please enter a valid email address." }, 400, cors);
  }

  if (!TURNSTILE_SECRET) {
    // Misconfigured function — fail closed.
    return json({ error: "Signup is temporarily unavailable." }, 503, cors);
  }

  if (!token) {
    return json({ error: "Please complete the captcha." }, 400, cors);
  }

  const human = await verifyTurnstile(token, ip);
  if (!human) {
    return json({ error: "Captcha verification failed. Please try again." }, 400, cors);
  }

  const result = await insertEmail(email);
  if (!result) {
    return json({ error: "Something went wrong. Please try again." }, 500, cors);
  }

  // Same success response whether it's a new signup or a duplicate, so the
  // endpoint doesn't reveal whether an address is already on the list.
  return json({ ok: true }, 201, cors);
});
