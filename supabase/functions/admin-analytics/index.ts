import { createClient } from "jsr:@supabase/supabase-js@2";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((v) => v.trim()).filter(Boolean);
const cors = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin && allowedOrigins.includes(origin) ? origin : "",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
});
const json = (body: unknown, status: number, headers: HeadersInit) =>
  new Response(JSON.stringify(body), { status, headers: { ...headers, "content-type": "application/json" } });

const dayKey = (timestampMs: number, offsetMinutes: number) => {
  const d = new Date(timestampMs + offsetMinutes * 60_000);
  return d.toISOString().slice(0, 10);
};

function activeDuration(row: Record<string, unknown>): number {
  const stored = Number(row.duration_ms ?? 0);
  if (stored > 0) return stored;
  const start = Number(row.started_at_utc ?? 0);
  const end = Number(row.ended_at_utc ?? start);
  const paused = Number(row.paused_total_ms ?? 0);
  return Math.max(0, end - start - paused);
}

function streaks(daily: Map<string, number>, today: string) {
  const threshold = 10 * 60_000;
  const active = (key: string) => (daily.get(key) ?? 0) >= threshold;
  let current = 0;
  const todayDate = new Date(`${today}T00:00:00.000Z`);
  let cursor = new Date(todayDate);
  if (!active(today)) cursor.setUTCDate(cursor.getUTCDate() - 1);
  while (active(cursor.toISOString().slice(0, 10))) {
    current++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
    if (current > 3650) break;
  }
  const days = [...daily.keys()].sort();
  let best = 0;
  let run = 0;
  let previous: Date | null = null;
  for (const key of days) {
    const date = new Date(`${key}T00:00:00.000Z`);
    if (!active(key)) { run = 0; previous = date; continue; }
    if (previous && (date.getTime() - previous.getTime()) / 86_400_000 === 1) run++;
    else run = 1;
    best = Math.max(best, run);
    previous = date;
  }
  return { currentStreak: current, bestStreak: best };
}

Deno.serve(async (req) => {
  const headers = cors(req.headers.get("origin"));
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405, headers);

  const authorization = req.headers.get("authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Unauthorized" }, 401, headers);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const userClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: { user }, error: authError } = await userClient.auth.getUser(token);
  if (authError || !user) return json({ error: "Unauthorized" }, 401, headers);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: role, error: roleError } = await admin
    .from("admin_allowlist")
    .select("user_id")
    .eq("user_id", user.id)
    .maybeSingle();
  if (roleError) return json({ error: "Could not verify administrator access" }, 500, headers);
  if (!role) return json({ isAdmin: false, error: "Forbidden" }, 403, headers);

  const body = await req.json().catch(() => ({}));
  if (body?.action === "access") return json({ isAdmin: true }, 200, headers);
  if (body?.action !== "dashboard") return json({ error: "Unsupported action" }, 400, headers);

  try {
    const authUsers: Record<string, any> = {};
    for (let page = 1; page <= 100; page++) {
      const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) throw error;
      for (const u of data.users) authUsers[u.id] = u;
      if (data.users.length < 1000) break;
    }

    const sessions: Record<string, any>[] = [];
    for (let from = 0; ; from += 1000) {
      const { data, error } = await admin
        .from("reading_sessions")
        .select("user_id, started_at_utc, ended_at_utc, duration_ms, paused_total_ms, tz_offset_min, deleted_at_ms")
        .is("deleted_at_ms", null)
        .not("ended_at_utc", "is", null)
        .range(from, from + 999);
      if (error) throw error;
      sessions.push(...(data ?? []));
      if (!data || data.length < 1000) break;
    }

    const byUser = new Map<string, { total: number; count: number; last: number; offset: number; daily: Map<string, number> }>();
    const globalDaily = new Map<string, number>();
    for (const row of sessions) {
      const uid = String(row.user_id);
      if (!authUsers[uid]) continue;
      const duration = activeDuration(row);
      if (duration <= 0) continue;
      const start = Number(row.started_at_utc);
      const offset = Number(row.tz_offset_min ?? 0);
      const day = dayKey(start, offset);
      const aggregate = byUser.get(uid) ?? { total: 0, count: 0, last: 0, offset, daily: new Map<string, number>() };
      aggregate.total += duration;
      aggregate.count++;
      aggregate.last = Math.max(aggregate.last, Number(row.ended_at_utc ?? start));
      aggregate.offset = offset;
      aggregate.daily.set(day, (aggregate.daily.get(day) ?? 0) + duration);
      byUser.set(uid, aggregate);
      globalDaily.set(day, (globalDaily.get(day) ?? 0) + duration);
    }

    const now = Date.now();
    const clients = Object.values(authUsers).map((u: any) => {
      const a = byUser.get(u.id) ?? { total: 0, count: 0, last: 0, offset: 0, daily: new Map<string, number>() };
      const today = dayKey(now, a.offset);
      const sevenDayStart = new Date(`${today}T00:00:00.000Z`);
      sevenDayStart.setUTCDate(sevenDayStart.getUTCDate() - 6);
      let week = 0;
      for (let i = 0; i < 7; i++) {
        const d = new Date(sevenDayStart);
        d.setUTCDate(d.getUTCDate() + i);
        week += a.daily.get(d.toISOString().slice(0, 10)) ?? 0;
      }
      const s = streaks(a.daily, today);
      const metadata = u.user_metadata ?? {};
      return {
        id: u.id,
        email: u.email ?? "",
        name: metadata.full_name ?? metadata.name ?? metadata.display_name ?? (u.email ?? "PageClock client").split("@")[0],
        avatarUrl: metadata.avatar_url ?? metadata.picture ?? null,
        createdAt: u.created_at,
        lastSignInAt: u.last_sign_in_at,
        lastActiveAt: a.last ? new Date(a.last).toISOString() : null,
        totalFocusMs: a.total,
        weekFocusMs: week,
        sessionCount: a.count,
        currentStreak: s.currentStreak,
        bestStreak: s.bestStreak,
        dailyFocusMs: Object.fromEntries(a.daily),
      };
    });

    clients.sort((a, b) => b.totalFocusMs - a.totalFocusMs);
    const todayKey = new Date(now).toISOString().slice(0, 10);
    const chart = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now);
      d.setUTCDate(d.getUTCDate() - i);
      const key = d.toISOString().slice(0, 10);
      chart.push({ date: key, focusMs: globalDaily.get(key) ?? 0 });
    }
    const activeToday = clients.filter((c) => c.lastActiveAt && dayKey(Date.parse(c.lastActiveAt), 0) === todayKey).length;
    const activeSevenDays = clients.filter((c) => c.lastActiveAt && Date.parse(c.lastActiveAt) >= now - 7 * 86_400_000).length;
    return json({
      isAdmin: true,
      generatedAt: new Date(now).toISOString(),
      summary: {
        totalClients: clients.length,
        activeToday,
        activeSevenDays,
        totalFocusMs: clients.reduce((sum, c) => sum + c.totalFocusMs, 0),
        totalSessions: clients.reduce((sum, c) => sum + c.sessionCount, 0),
      },
      dailyFocus: chart,
      clients,
    }, 200, headers);
  } catch (error) {
    console.error("[admin-analytics]", error);
    return json({ error: "Admin analytics could not be loaded" }, 500, headers);
  }
});
