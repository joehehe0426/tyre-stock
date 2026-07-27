/**
 * Cloudflare Worker: auth gate + Wheel Size API proxy for GitHub Pages origin.
 * Secret: WHEEL_SIZE_USER_KEY (wrangler secret put WHEEL_SIZE_USER_KEY)
 */
const DEFAULT_USER = "madam";
const DEFAULT_PASS = "250183418";
const ORIGIN = "https://joehehe0426.github.io";
const ORIGIN_PREFIX = "/tyre-stock";
const WS_API = "https://api.wheel-size.com/v2";
/** HK has no hkdm slug — use common import markets. */
const DEFAULT_REGIONS = ["jdm", "eudm", "sam"];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS" && url.pathname.startsWith("/api/")) {
      return corsPreflight(request);
    }

    const authed = isAuthed(request, env);

    if (url.pathname.startsWith("/api/ws/")) {
      if (!authed) {
        return withCors(
          request,
          json({ error: "Unauthorized" }, 401),
        );
      }
      try {
        return withCors(request, await handleWsApi(url, env));
      } catch (e) {
        return withCors(
          request,
          json({ error: String(e && e.message ? e.message : e) }, 502),
        );
      }
    }

    if (authed) {
      return proxyToOrigin(request, url);
    }

    const auth = request.headers.get("Authorization");
    if (auth && auth.startsWith("Basic ")) {
      try {
        const decoded = atob(auth.slice(6));
        const colon = decoded.indexOf(":");
        const u = colon >= 0 ? decoded.slice(0, colon) : decoded;
        const p = colon >= 0 ? decoded.slice(colon + 1) : "";
        const user = (env && env.AUTH_USER) || DEFAULT_USER;
        const pass = (env && env.AUTH_PASS) || DEFAULT_PASS;
        if (u === user && p === pass) {
          const resp = await proxyToOrigin(request, url);
          const headers = new Headers(resp.headers);
          headers.append(
            "Set-Cookie",
            "auth=ok; Path=/; Max-Age=86400; SameSite=Lax; Secure",
          );
          headers.set("X-Tyre-Worker", "1");
          return new Response(resp.body, {
            status: resp.status,
            statusText: resp.statusText,
            headers,
          });
        }
      } catch (_) {
        /* fall through */
      }
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

function isAuthed(request, env) {
  const cookie = request.headers.get("Cookie") || "";
  if (cookie.includes("auth=ok")) return true;

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
  if (
    origin === "https://joehehe0426.github.io" ||
    origin === "https://tyre.autragroupltd.com" ||
    origin.startsWith("http://localhost") ||
    origin.startsWith("http://127.0.0.1")
  ) {
    return origin;
  }
  return "";
}

function corsPreflight(request) {
  const origin = allowedOrigin(request);
  const headers = new Headers({
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Max-Age": "86400",
    "X-Tyre-Worker": "1",
  });
  if (origin) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Access-Control-Allow-Credentials", "true");
  }
  return new Response(null, { status: 204, headers });
}

function withCors(request, response) {
  const origin = allowedOrigin(request);
  if (!origin) return response;
  const headers = new Headers(response.headers);
  headers.set("Access-Control-Allow-Origin", origin);
  headers.set("Access-Control-Allow-Credentials", "true");
  headers.set("Vary", "Origin");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

async function handleWsApi(url, env) {
  const key = env && env.WHEEL_SIZE_USER_KEY;
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
  // ["api","ws","makes"] or ["api","ws","search"]
  const action = parts[2] || "";
  const q = url.searchParams;

  const upstream = new URL(WS_API + "/");
  const params = new URLSearchParams();
  params.set("user_key", key);

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
  upstream.pathname = "/v2/" + map[action];

  // Forward selected query params
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
  ]) {
    const v = q.get(name);
    if (v != null && v !== "") params.set(name, v);
  }

  // List endpoints: apply default multi-region if none provided
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
  // search/by_model allows only one region
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
