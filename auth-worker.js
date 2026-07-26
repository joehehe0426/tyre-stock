export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const AUTH_USER = "madam";
    const AUTH_PASS = "tyre888";

    // Check for auth cookie
    const cookie = request.headers.get("Cookie") || "";
    if (cookie.includes("auth=ok")) {
      return await fetchOrigin(request, url);
    }

    // Check for Authorization header (Basic Auth)
    const auth = request.headers.get("Authorization");
    if (auth && auth.startsWith("Basic ")) {
      const decoded = atob(auth.slice(6));
      const [user, pass] = decoded.split(":");
      if (user === AUTH_USER && pass === AUTH_PASS) {
        const resp = await fetchOrigin(request, url);
        resp.headers.append("Set-Cookie", "auth=ok; Path=/; Max-Age=86400; SameSite=Lax");
        return resp;
      }
    }

    // Show login page
    return new Response(getLoginHtml(), {
      status: 401,
      headers: { "Content-Type": "text/html; charset=utf-8", "WWW-Authenticate": 'Basic realm="呔妹輪胎"' },
    });
  },
};

async function fetchOrigin(request, url) {
  const origin = "https://joehehe0426.github.io";
  url.hostname = "joehehe0426.github.io";
  url.pathname = "/tyre-stock" + url.pathname.replace(/\/$/, "") || "/tyre-stock";
  const resp = await fetch(url.toString(), { method: request.method, headers: request.headers, body: request.body });
  return resp;
}

function getLoginHtml() {
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
button{width:100%;padding:12px;background:#d81b60;color:#fff;border:none;border-radius:12px;font-size:16px;cursor:pointer;transition:background .2s}
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
  const r=await fetch(location.href,{headers:{Authorization:'Basic '+btoa('madam:'+p)}});
  if(r.ok)location.reload();
  else document.getElementById('err').style.display='block';
}
<\/script>
</body></html>`;
}
