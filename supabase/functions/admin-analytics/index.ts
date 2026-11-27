import { createClient } from "jsr:@supabase/supabase-js@2";

const allowedOrigins = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((v) => v.trim()).filter(Boolean);
const cors = (origin: string | null) => ({
  "Access-Control-Allow-Origin": origin && (allowedOrigins.length === 0 || allowedOrigins.includes(origin)) ? origin : "",
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

type Interval = { start: number; end: number };

function activeIntervals(row: Record<string, unknown>): Interval[] {
  const start = Number(row.started_at_utc ?? 0);
  const end = Number(row.ended_at_utc ?? start);
  const pausedTotal = Math.max(0, Number(row.paused_total_ms ?? 0));
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return [];

  const raw = Array.isArray(row.pause_intervals) ? row.pause_intervals : [];
  const pauses: Interval[] = raw.flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const value = item as Record<string, unknown>;
    const pauseStart = Number(value.start_utc);
    const pauseEnd = Number(value.end_utc);
    return Number.isFinite(pauseStart) && Number.isFinite(pauseEnd) && pauseEnd > pauseStart
      ? [{ start: Math.max(start, pauseStart), end: Math.min(end, pauseEnd) }]
      : [];
  }).filter((pause) => pause.end > pause.start).sort((a, b) => a.start - b.start);

  // For completed sessions, duration_ms is the persisted net focus time.
  // It remains authoritative when an older row has missing/incomplete pause
  // metadata; otherwise wall-clock elapsed time can overcount (15 focused
  // minutes recorded across a 45-minute span was previously reported as 45).
  if (pauses.length === 0) {
    const stored = Math.max(0, Number(row.duration_ms ?? 0));
    const active = stored > 0 ? stored : end - start - pausedTotal;
    const fallbackEnd = Math.min(end, start + Math.max(0, active));
    return fallbackEnd > start ? [{ start, end: fallbackEnd }] : [];
  }

  const merged: Interval[] = [];
  for (const pause of pauses) {
    const previous = merged[merged.length - 1];
    if (previous && pause.start <= previous.end) previous.end = Math.max(previous.end, pause.end);
    else merged.push({ ...pause });
  }

  // Older app versions may have accumulated pause time without exact intervals.
  let unlocatedPause = pausedTotal - merged.reduce((sum, pause) => sum + pause.end - pause.start, 0);
  if (unlocatedPause > 0) {
    let cursor = start;
    const fallback: Interval[] = [];
    for (const pause of merged) {
      const gap = pause.start - cursor;
      if (gap > 0 && unlocatedPause > 0) {
        const allocated = Math.min(gap, unlocatedPause);
        fallback.push({ start: cursor, end: cursor + allocated });
        unlocatedPause -= allocated;
      }
      cursor = Math.max(cursor, pause.end);
      if (unlocatedPause <= 0) break;
    }
    if (unlocatedPause > 0 && cursor < end) {
      const allocated = Math.min(end - cursor, unlocatedPause);
      fallback.push({ start: cursor, end: cursor + allocated });
    }
    pauses.push(...fallback);
    pauses.sort((a, b) => a.start - b.start);
  }

  const focused: Interval[] = [];
  let cursor = start;
  for (const pause of pauses) {
    if (pause.end <= cursor || pause.end <= pause.start) continue;
    if (pause.start > cursor) focused.push({ start: cursor, end: pause.start });
    cursor = Math.max(cursor, pause.end);
    if (cursor >= end) break;
  }
  if (cursor < end) focused.push({ start: cursor, end });

  // If pause records are incomplete, fall back to the persisted net duration
  // rather than allowing interval reconstruction to inflate admin totals.
  const stored = Math.max(0, Number(row.duration_ms ?? 0));
  if (stored > 0) {
    const expected = Math.min(end - start, stored);
    const reconstructed = focused.reduce((sum, interval) => sum + interval.end - interval.start, 0);
    if (reconstructed !== expected) {
      const fallbackEnd = start + expected;
      return fallbackEnd > start ? [{ start, end: fallbackEnd }] : [];
    }
  }
  return focused;
}

function addIntervalByLocalDay(
  daily: Map<string, number>,
  interval: Interval,
  offsetMinutes: number,
): void {
  let cursor = interval.start;
  while (cursor < interval.end) {
    const key = dayKey(cursor, offsetMinutes);
    const nextLocalMidnight = Date.parse(`${key}T00:00:00.000Z`) + 86_400_000 - offsetMinutes * 60_000;
    const segmentEnd = Math.min(interval.end, nextLocalMidnight);
    if (segmentEnd <= cursor) break;
    daily.set(key, (daily.get(key) ?? 0) + segmentEnd - cursor);
    cursor = segmentEnd;
  }
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

    const { data: countryRows, error: countryError } = await admin.from("signup_country_capture").select("user_id, country_code, country_name, detected_at");
    if (countryError) throw countryError;
    const signupCountries = new Map<string, Record<string, unknown>>();
    for (const row of countryRows ?? []) signupCountries.set(String(row.user_id), row);

    // Keyset pagination on the unique monotonic server_seq avoids unstable
    // offset pages when the table grows or PostgREST's row ordering changes.
    const sessions: Record<string, any>[] = [];
    let cursor = 0;
    const pageSize = 1000;
    for (;;) {
      const { data, error } = await admin
        .from("reading_sessions")
        .select("user_id, server_seq, started_at_utc, ended_at_utc, duration_ms, paused_total_ms, pause_intervals, tz_offset_min, deleted_at_ms")
        .is("deleted_at_ms", null)
        .not("ended_at_utc", "is", null)
        .gt("server_seq", cursor)
        .order("server_seq", { ascending: true })
        .limit(pageSize);
      if (error) throw error;
      if (!data || data.length === 0) break;
      sessions.push(...data);
      cursor = Number(data[data.length - 1].server_seq);
      if (data.length < pageSize) break;
    }

    const byUser = new Map<string, { total: number; count: number; last: number; offset: number; daily: Map<string, number> }>();
    const globalDaily = new Map<string, number>();
    for (const row of sessions) {
      const uid = String(row.user_id);
      if (!authUsers[uid] || uid === user.id) continue;
      const intervals = activeIntervals(row);
      const duration = intervals.reduce((sum, interval) => sum + interval.end - interval.start, 0);
      if (duration <= 0) continue;
      const offset = Number(row.tz_offset_min ?? 0);
      const aggregate = byUser.get(uid) ?? { total: 0, count: 0, last: 0, offset, daily: new Map<string, number>() };
      aggregate.total += duration;
      aggregate.count++;
      aggregate.last = Math.max(aggregate.last, Number(row.ended_at_utc ?? row.started_at_utc ?? 0));
      aggregate.offset = offset;
      for (const interval of intervals) {
        addIntervalByLocalDay(aggregate.daily, interval, offset);
        addIntervalByLocalDay(globalDaily, interval, 0);
      }
      byUser.set(uid, aggregate);
    }

    const now = Date.now();
    const clients = Object.values(authUsers).filter((u: any) => u.id !== user.id).map((u: any) => {
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
      const country = signupCountries.get(u.id);
      return {
        id: u.id,
        authProvider: String(u.app_metadata?.provider ?? (u.app_metadata?.providers?.[0] ?? "unknown")),
        signupCountryCode: country?.country_code ?? null,
        signupCountryName: country?.country_name ?? null,
        signupCountryDetectedAt: country?.detected_at ?? null,
        email: u.email ?? "",
        name: metadata.full_name ?? metadata.name ?? metadata.display_name ?? (u.email ?? "PageClock client").split("@")[0],
        avatarUrl: metadata.avatar_url ?? metadata.picture ?? null,
        createdAt: u.created_at,
        lastSignInAt: u.last_sign_in_at,
        lastActiveAt: a.last ? new Date(a.last).toISOString() : null,
        totalFocusMs: a.total,
        weekFocusMs: week,
        todayFocusMs: a.daily.get(today) ?? 0,
        sessionCount: a.count,
        currentStreak: s.currentStreak,
        bestStreak: s.bestStreak,
        isActiveToday: (a.daily.get(today) ?? 0) > 0,
        dailyFocusMs: Object.fromEntries(a.daily),
      };
    });

    clients.sort((a, b) => b.totalFocusMs - a.totalFocusMs);
    const chart = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now);
      d.setUTCDate(d.getUTCDate() - i);
      const key = d.toISOString().slice(0, 10);
      chart.push({ date: key, focusMs: globalDaily.get(key) ?? 0 });
    }
    const activeToday = clients.filter((c) => c.isActiveToday).length;
    const activeSevenDays = clients.filter((c) => c.lastActiveAt && Date.parse(c.lastActiveAt) >= now - 7 * 86_400_000).length;
    const countryDistribution: Record<string, { countryCode: string; countryName: string; clients: number }> = {};
    for (const client of clients) {
      if (!client.signupCountryCode || !client.signupCountryName) continue;
      const code = String(client.signupCountryCode);
      const entry = countryDistribution[code] ?? { countryCode: code, countryName: String(client.signupCountryName), clients: 0 };
      entry.clients++;
      countryDistribution[code] = entry;
    }
    return json({
      isAdmin: true,
      generatedAt: new Date(now).toISOString(),
      summary: {
        totalClients: clients.length,
        activeToday,
        activeSevenDays,
        totalFocusMs: clients.reduce((sum, c) => sum + c.totalFocusMs, 0),
        totalSessions: clients.reduce((sum, c) => sum + c.sessionCount, 0),
        countriesReached: Object.keys(countryDistribution).length,
        countryDetectedClients: clients.filter((c) => c.signupCountryCode != null).length,
      },
      countryDistribution: Object.values(countryDistribution).sort((a, b) => b.clients - a.clients),
      dailyFocus: chart,
      clients,
    }, 200, headers);
  } catch (error) {
    console.error("[admin-analytics]", error);
    return json({ error: "Admin analytics could not be loaded" }, 500, headers);
  }
});
