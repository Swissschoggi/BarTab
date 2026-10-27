// Vercel serverless proxy for the Supabase `waitlist` edge function.
//
// Why this exists: calling Supabase directly from the browser hits CORS, and
// the edge function's allow-list of origins is brittle (preview URLs, www vs
// apex, localhost). Routing through this same-origin function sidesteps CORS
// entirely — the browser only ever talks to /api/waitlist on bartap.info.
//
// The Supabase call happens server-side, so CORS headers on the upstream
// response are irrelevant.

const SUPABASE_URL = "https://xdyewakhzjnmpzhzhehl.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhkeWV3YWtoempubXB6aHpoZWhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcwODc2MjksImV4cCI6MjEwMjY2MzYyOX0.nAZASYlhS3OBFc-mBSUVenGUTuzfMZgcbt9eBhc4Dm4";
const UPSTREAM = `${SUPABASE_URL}/functions/v1/waitlist`;

module.exports = async (req, res) => {
  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    const upstream = await fetch(UPSTREAM, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_ANON_KEY,
        Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
        "x-forwarded-for": req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "",
      },
      body: JSON.stringify(req.body ?? {}),
    });

    const text = await upstream.text();
    let data;
    try {
      data = text ? JSON.parse(text) : {};
    } catch {
      data = { raw: text };
    }

    res.status(upstream.status).json(data);
  } catch (err) {
    res.status(502).json({ error: "Upstream request failed. Please try again." });
  }
};
