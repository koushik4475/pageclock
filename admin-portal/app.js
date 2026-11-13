import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./config.js";

const login = document.querySelector("#login");
const dashboard = document.querySelector("#dashboard");
const signout = document.querySelector("#signout");
const loginForm = document.querySelector("#login-form");
const loginError = document.querySelector("#login-error");
const status = document.querySelector("#status");
const tbody = document.querySelector("#clients");
const search = document.querySelector("#search");
const searchButton = document.querySelector("#search-button");
const loadMore = document.querySelector("#load-more");
const count = document.querySelector("#loaded-count");
const pageSize = 25;
let offset = 0;
let hasMore = false;
let supabase;

function showError(message) {
  status.textContent = message;
  status.className = "error";
}
function formatDate(value) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? "—" : date.toLocaleString();
}
function showSignedOut() {
  login.classList.remove("hidden");
  dashboard.classList.add("hidden");
  signout.classList.add("hidden");
}
function showDashboard() {
  login.classList.add("hidden");
  dashboard.classList.remove("hidden");
  signout.classList.remove("hidden");
}

async function verifyAdmin() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return false;
  const { data, error } = await supabase
    .from("admin_roles")
    .select("role")
    .eq("user_id", user.id)
    .maybeSingle();
  if (error) throw error;
  return ["super_admin", "admin"].includes(data?.role);
}

async function loadClients(reset = false) {
  if (reset) {
    offset = 0;
    tbody.replaceChildren();
  }
  status.textContent = "Loading client accounts…";
  status.className = "muted";
  loadMore.classList.add("hidden");
  let query = supabase
    .from("profiles")
    .select("id, display_name, email, created_at")
    .order("created_at", { ascending: false })
    .range(offset, offset + pageSize - 1);
  const term = search.value.trim();
  if (term) query = query.ilike("email", `%${term}%`);
  const { data, error } = await query;
  if (error) {
    showError("Unable to load accounts. Verify administrator access and the database migrations.");
    return;
  }
  for (const row of data ?? []) {
    const tr = document.createElement("tr");
    const name = document.createElement("td");
    const email = document.createElement("td");
    const created = document.createElement("td");
    name.textContent = row.display_name || "PageClock client";
    email.textContent = row.email || "—";
    created.textContent = formatDate(row.created_at);
    tr.append(name, email, created);
    tbody.append(tr);
  }
  offset += data?.length ?? 0;
  hasMore = (data?.length ?? 0) === pageSize;
  count.textContent = `${offset} loaded`;
  status.textContent = data?.length ? "Account metadata loaded." : (offset ? "No more accounts." : "No client accounts found.");
  loadMore.classList.toggle("hidden", !hasMore);
}

async function enterDashboard() {
  const allowed = await verifyAdmin();
  if (!allowed) {
    await supabase.auth.signOut();
    showSignedOut();
    loginError.textContent = "This account does not have an administrator role.";
    return;
  }
  showDashboard();
  await loadClients(true);
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  loginError.textContent = "";
  const button = loginForm.querySelector("button");
  button.disabled = true;
  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: document.querySelector("#email").value.trim(),
      password: document.querySelector("#password").value,
    });
    if (error) throw error;
    await enterDashboard();
  } catch (error) {
    loginError.textContent = error?.message || "Sign in failed.";
  } finally {
    button.disabled = false;
  }
});

signout.addEventListener("click", async () => {
  await supabase.auth.signOut();
  showSignedOut();
});
searchButton.addEventListener("click", () => loadClients(true));
search.addEventListener("keydown", (event) => {
  if (event.key === "Enter") loadClients(true);
});
loadMore.addEventListener("click", () => loadClients(false));

if (!SUPABASE_URL.startsWith("https://") || SUPABASE_ANON_KEY.startsWith("YOUR_")) {
  loginError.textContent = "Configure admin-portal/config.js with your Supabase URL and public key before hosting.";
} else {
  supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const { data: { session } } = await supabase.auth.getSession();
  if (session) {
    try { await enterDashboard(); } catch { showSignedOut(); }
  } else {
    showSignedOut();
  }
  supabase.auth.onAuthStateChange((_event, session) => {
    if (!session) showSignedOut();
  });
}
