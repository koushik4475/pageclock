import { createClient } from "jsr:@supabase/supabase-js@2";
const allowed = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",");   // exact origins only
const cors = (o: string | null) => ({
  "Access-Control-Allow-Origin": o && allowed.includes(o) ? o : "",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
});
Deno.serve(async (req) => {
  const h = cors(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: h });
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: h });
  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer /i, "");
  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!);
  const { data: { user }, error } = await userClient.auth.getUser(jwt);   // target = caller; never from the body
  if (error || !user) return new Response("Unauthorized", { status: 401, headers: h });
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);   // cascades reading_sessions
  return new Response(JSON.stringify({ ok: !delErr }), { status: delErr ? 500 : 200, headers: { ...h, "content-type": "application/json" } });
});
