// Supabase Edge Function: delete-account
//
// Permanently deletes the calling user's auth account (and, via ON DELETE
// CASCADE, all their data). Must be invoked with the user's JWT.
//
// Deploy:
//   supabase functions deploy delete-account
// Then set the secret:
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
//
// The anon key + URL are already available as built-in secrets.

import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const headers = { "Content-Type": "application/json" };

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers,
    });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    return new Response(JSON.stringify({ error: "Missing token" }), {
      status: 401,
      headers,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Server not configured for account deletion" }),
      { status: 500, headers },
    );
  }

  // 1. Verify the caller using their own JWT.
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers,
    });
  }

  // 2. Delete the user with the service role key.
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    user.id,
  );

  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers,
    });
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers,
  });
});
