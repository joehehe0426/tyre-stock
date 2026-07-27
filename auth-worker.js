/**
 * Cloudflare Worker: signed-session auth gate + Wheel Size API proxy.
 * Wheel Size key is ONLY used on tyre.autragroupltd.com.
 *
 * Secrets:
 *   WHEEL_SIZE_USER_KEY (or WHEEL_SIZE_API_KEY)
 *   AUTH_PASS (optional; falls back to DEFAULT_PASS)
 *   AUTH_USER (optional; falls back to DEFAULT_USER)
 */
const DEFAULT_USER = "madam";
const DEFAULT_PASS = "250183418";
const ORIGIN = "https://joehehe0426.github.io";
const ORIGIN_PREFIX = "/tyre-stock";
const WS_API = "https://api.wheel-size.com/v2";
const AUTRA_HOST = "tyre.autragroupltd.com";
const SESSION_TTL_SEC = 86400;
/** HK has no hkdm slug — use common import markets. */
const DEFAULT_REGIONS = ["jdm", "eudm", "sam"];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS" && url.pathname.startsWith("/api/")) {
      return corsPreflight(request);
    }

    const cookieOk = await isCookieAuthed(request, env);
    const basicOk = await isBasicAuthed(request, env);
    const authed = cookieOk || basicOk;

    if (url.pathname.startsWith("/api/ws/")) {
      if (!isAutraHost(url)) {
        return json(
          { error: "Wheel Size API is only available on tyre.autragroupltd.com" },
          403,
        );
      }
      if (!isAutraClient(request)) {
        return json({ error: "Forbidden origin" }, 403);
      }
      if (!authed) {
        return json({ error: "Unauthorized" }, 401);
      }
      try {
        return await handleWsApi(url, env);
      } catch (e) {
        return json({ error: String(e && e.message ? e.message : e) }, 502);
      }
    }

    if (authed) {
      const resp = await proxyToOrigin(request, url);
      // Login via Basic must mint a cookie, otherwise reload loses auth.
      if (basicOk && !cookieOk) {
        return withSessionCookie(resp, await mintSessionCookie(env));
      }
      return resp;
    }

    return new Response(loginHtml(), {
      status: 401,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Tyre-Worker": "1",
      },
    });
  },
};

function isAutraHost(url) {
  return url.hostname === AUTRA_HOST;
}

function isAutraClient(request) {
  const origin = request.headers.get("Origin") || "";
  if (!origin) return true;
  try {
    return new URL(origin).hostname === AUTRA_HOST;
  } catch (_) {
    return false;
  }
}

function authSecret(env) {
  return (env && env.AUTH_PASS) || DEFAULT_PASS;
}

async function hmacHex(secret, message) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return [...new Uint8Array(sig)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return out === 0;
}

async function mintSessionCookie(env) {
  const exp = Math.floor(Date.now() / 1000) + SESSION_TTL_SEC;
  const payload = `v1.${exp}`;
  const sig = await hmacHex(authSecret(env), payload);
  return `auth=${payload}.${sig}; Path=/; Max-Age=${SESSION_TTL_SEC}; SameSite=Lax; Secure; HttpOnly`;
}

function readAuthCookie(cookieHeader) {
  const parts = (cookieHeader || "").split(";");
  for (const part of parts) {
    const trimmed = part.trim();
    if (trimmed.startsWith("auth=")) return trimmed.slice(5);
  }
  return "";
}

async function isCookieAuthed(request, env) {
  const token = readAuthCookie(request.headers.get("Cookie") || "");
  // Reject legacy forgeable "auth=ok"
  if (!token || token === "ok") return false;
  const bits = token.split(".");
  if (bits.length !== 3 || bits[0] !== "v1") return false;
  const exp = Number(bits[1]);
  const payload = `${bits[0]}.${bits[1]}`;
  const sig = bits[2];
  if (!Number.isFinite(exp) || exp <= Date.now() / 1000) return false;
  const expected = await hmacHex(authSecret(env), payload);
  return timingSafeEqual(sig, expected);
}

async function isBasicAuthed(request, env) {
  const auth = request.headers.get("Authorization");
  if (!auth || !auth.startsWith("Basic ")) return false;
  try {
    const decoded = atob(auth.slice(6));
    const colon = decoded.indexOf(":");
    const u = colon >= 0 ? decoded.slice(0, colon) : decoded;
    const p = colon >= 0 ? decoded.slice(colon + 1) : "";
    const user = (env && env.AUTH_USER) || DEFAULT_USER;
    const pass = (env && env.AUTH_PASS) || DEFAULT_PASS;
    return u === user && p === pass;
  } catch (_) {
    return false;
  }
}

function withSessionCookie(resp, cookie) {
  const out = new Headers();
  const ctype = resp.headers.get("content-type");
  if (ctype) out.set("Content-Type", ctype);
  out.set("Cache-Control", "no-store");
  out.set("Set-Cookie", cookie);
  out.set("X-Tyre-Worker", "1");
  return new Response(resp.body, {
    status: resp.status,
    statusText: resp.statusText,
    headers: out,
  });
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Tyre-Worker": "1",
    },
  });
}

function allowedOrigin(request) {
  const origin = request.headers.get("Origin") || "";
  if (origin === `https://${AUTRA_HOST}`) return origin;
  return "";
}

function corsPreflight(request) {
  const origin = allowedOrigin(request);
  if (!origin) return json({ error: "Forbidden origin" }, 403);
  return new Response(null, {
    status: 204,
    headers: {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Credentials": "true",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Authorization, Content-Type",
      "Access-Control-Max-Age": "86400",
      "X-Tyre-Worker": "1",
      Vary: "Origin",
    },
  });
}

async function handleWsApi(url, env) {
  const key =
    (env && (env.WHEEL_SIZE_USER_KEY || env.WHEEL_SIZE_API_KEY)) || "";
  if (!key) {
    return json(
      {
        error:
          "WHEEL_SIZE_USER_KEY not configured. Run: npx wrangler secret put WHEEL_SIZE_USER_KEY",
      },
      503,
    );
  }

  const parts = url.pathname.replace(/\/+$/, "").split("/").filter(Boolean);
  const action = parts[2] || "";
  const q = url.searchParams;

  const map = {
    makes: "makes/",
    models: "models/",
    years: "years/",
    generations: "generations/",
    modifications: "modifications/",
    search: "search/by_model/",
    regions: "regions/",
  };
  if (!map[action]) {
    return json({ error: "Unknown endpoint", allowed: Object.keys(map) }, 404);
  }

  const upstream = new URL(WS_API + "/");
  upstream.pathname = "/v2/" + map[action];
  const params = new URLSearchParams();
  params.set("user_key", key);

  for (const name of [
    "make",
    "model",
    "year",
    "generation",
    "modification",
    "region",
    "lang",
    "limit",
    "offset",
    "ordering",
    "add_configurator",
  ]) {
    const v = q.get(name);
    if (v != null && v !== "") params.set(name, v);
  }

  const multiRegionActions = new Set([
    "makes",
    "models",
    "years",
    "generations",
    "modifications",
  ]);
  if (multiRegionActions.has(action) && !q.has("region")) {
    for (const r of DEFAULT_REGIONS) params.append("region", r);
  }
  if (action === "search" && !q.get("region")) {
    params.set("region", "jdm");
  }

  upstream.search = params.toString();
  const resp = await fetch(upstream.toString(), {
    method: "GET",
    headers: { Accept: "application/json" },
  });
  const text = await resp.text();
  return new Response(text, {
    status: resp.status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Tyre-Worker": "1",
      "X-WS-Upstream-Status": String(resp.status),
    },
  });
}

async function proxyToOrigin(request, url) {
  let path = url.pathname || "/";
  if (path === ORIGIN_PREFIX || path.startsWith(ORIGIN_PREFIX + "/")) {
    // already prefixed
  } else if (path === "/") {
    path = ORIGIN_PREFIX + "/";
  } else {
    path = ORIGIN_PREFIX + path;
  }

  const target = new URL(ORIGIN + path);
  target.search = url.search;

  const headers = new Headers(request.headers);
  headers.delete("host");
  headers.delete("cf-connecting-ip");
  headers.delete("cf-ray");
  headers.delete("cf-visitor");
  headers.delete("authorization");

  const init = {
    method: request.method,
    headers,
    redirect: "follow",
  };
  if (request.method !== "GET" && request.method !== "HEAD") {
    init.body = request.body;
  }

  const upstream = await fetch(target.toString(), init);
  const outHeaders = new Headers(upstream.headers);
  outHeaders.set("X-Tyre-Worker", "1");
  const ctype = outHeaders.get("content-type") || "";
  if (ctype.includes("text/html")) {
    let html = await upstream.text();
    html = html.replaceAll('href="/tyre-stock/"', 'href="/"');
    html = html.replaceAll("href='/tyre-stock/'", "href='/'");
    outHeaders.delete("content-length");
    return new Response(html, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers: outHeaders,
    });
  }

  return new Response(upstream.body, {
    status: upstream.status,
    statusText: upstream.statusText,
    headers: outHeaders,
  });
}

function loginHtml() {
  return `<!DOCTYPE html>
<html lang="zh-TW"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>呔妹輪胎 — 登入</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#fce4ec,#f8bbd0);min-height:100vh;display:flex;align-items:center;justify-content:center}
.card{background:#fff;border-radius:20px;padding:40px;width:340px;box-shadow:0 10px 40px rgba(0,0,0,.1);text-align:center}
.logo{width:80px;height:80px;border-radius:50%;background:#d81b60;display:flex;align-items:center;justify-content:center;margin:0 auto 16px;font-size:36px;color:#fff}
h1{font-size:20px;color:#333;margin-bottom:4px}
p{color:#888;font-size:13px;margin-bottom:24px}
input{width:100%;padding:12px 16px;border:2px solid #eee;border-radius:12px;font-size:15px;margin-bottom:12px;outline:none;transition:border .2s}
input:focus{border-color:#d81b60}
button{width:100%;padding:12px;background:#d81b60;color:#fff;border:none;border-radius:12px;font-size:16px;cursor:pointer}
button:hover{background:#c2185b}
.error{color:#d32f2f;font-size:13px;margin-top:8px;display:none}
</style></head><body>
<div class="card"><div class="logo">🔐</div>
<h1>呔妹輪胎庫存</h1><p>請輸入密碼以繼續</p>
<input type="password" id="pass" placeholder="密碼" autofocus onkeydown="if(event.key==='Enter')login()">
<button onclick="login()">登入</button>
<p class="error" id="err">密碼錯誤</p></div>
<script>
async function login(){
  const p=document.getElementById('pass').value;
  const r=await fetch(location.href,{headers:{Authorization:'Basic '+btoa('madam:'+p)},cache:'no-store'});
  if(r.ok)location.reload();
  else document.getElementById('err').style.display='block';
}
<\/script>
</body></html>`;
}
