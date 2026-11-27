import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin ?? "",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
});
const reply = (body: unknown, status: number, headers: HeadersInit) =>
  new Response(JSON.stringify(body), { status, headers: { ...headers, "content-type": "application/json" } });

Deno.serve(async (req) => {
  const headers = cors(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405, headers);
  const token = (req.headers.get("authorization") ?? "").replace(/^Bearer\\s+/i, "");
  if (!token) return reply({ error: "Unauthorized" }, 401, headers);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: { user }, error } = await anon.auth.getUser(token);
  if (error || !user) return reply({ error: "Unauthorized" }, 401, headers);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: existing, error: readError } = await admin.from("client_onboarding").select("user_id,country_code,country_name").eq("user_id", user.id).maybeSingle();
  if (readError) return reply({ error: "Could not read onboarding attribution" }, 500, headers);
  if (existing) return reply({ recorded: true, alreadyRecorded: true }, 200, headers);

  // Only read proxy-provided address headers. Do not accept an IP supplied in the JSON body.
  const forwarded = req.headers.get("x-forwarded-for");
  const ip = req.headers.get("x-real-ip") ?? (forwarded ? forwarded.split(",").at(-1)?.trim() : null);
  let countryCode: string | null = null;
  let countryName: string | null = null;
  if (ip && !/^(127\\.|10\\.|192\\.168\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.|::1$|fc|fd)/i.test(ip)) {
    try {
      const response = await fetch("https://ipwho.is/" + encodeURIComponent(ip), { signal: AbortSignal.timeout(2500) });
      if (response.ok) {
        const geo = await response.json();
        if (geo.success === true && /^[A-Z]{2}$/.test(geo.country_code ?? "")) {
          countryCode = geo.country_code;
          countryName = typeof geo.country === "string" ? geo.country.slice(0, 100) : null;
        }
      }
    } catch (_) {
      // Attribution is best-effort and must never block sign-in.
    }
  }

  const { error: insertError } = await admin.from("client_onboarding").insert({
    user_id: user.id, country_code: countryCode, country_name: countryName,
    detection_source: "first_authenticated_app_session",
  });
  if (insertError && insertError.code !== "23505") return reply({ error: "Could not save onboarding attribution" }, 500, headers);
  return reply({ recorded: true, countryDetected: countryCode !== null }, 200, headers);
});
