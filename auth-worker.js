/**
 * Cloudflare Worker: Basic-auth gate in front of GitHub Pages.
 * Custom domain serves the app at "/" while origin lives under /tyre-stock/.
 *
 * Env (optional): AUTH_USER, AUTH_PASS — defaults match the in-app PIN flow.
 */
const DEFAULT_USER = "madam";
const DEFAULT_PASS = "250183418";
const ORIGIN = "https://joehehe0426.github.io";
const ORIGIN_PREFIX = "/tyre-stock";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const user = (env && env.AUTH_USER) || DEFAULT_USER;
    const pass = (env && env.AUTH_PASS) || DEFAULT_PASS;

    const cookie = request.headers.get("Cookie") || "";
    if (cookie.includes("auth=ok")) {
      return proxyToOrigin(request, url);
    }

    const auth = request.headers.get("Authorization");
    if (auth && auth.startsWith("Basic ")) {
      try {
        const decoded = atob(auth.slice(6));
        const colon = decoded.indexOf(":");
        const u = colon >= 0 ? decoded.slice(0, colon) : decoded;
        const p = colon >= 0 ? decoded.slice(colon + 1) : "";
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
        /* fall through to login */
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

async function proxyToOrigin(request, url) {
  let path = url.pathname || "/";
  // Avoid double-prefix if browser follows <base href="/tyre-stock/">
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
  headers.delete("authorization"); // don't forward basic auth to GitHub

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
  // HTML from GH Pages has base=/tyre-stock/; rewrite to / for custom domain root
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
