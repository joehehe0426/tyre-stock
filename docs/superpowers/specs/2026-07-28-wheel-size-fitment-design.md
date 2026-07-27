# Wheel-size live fitment (2026-07-28)

## Goal
Use Wheel Fitment API v2 via Cloudflare Worker so the API key never ships in the Flutter web bundle, and fitment works without a local PC.

## Decisions
- Proxy on existing Worker `tyre-stock-auth` under `/api/ws/*`
- Default markets for HK (no `hkdm` in API): `jdm`, `eudm`, `sam`
- UI: toggle **線上 (API)** / **本機 JSON**; online first when on custom domain
- Auth: same gate as site (cookie `auth=ok` or Basic). Flutter sends Basic using in-app PIN so GitHub Pages can call the API with CORS
- Secret: Cloudflare `WHEEL_SIZE_USER_KEY` (wrangler secret) — never commit

## Endpoints (Worker → api.wheel-size.com/v2)
| App path | Upstream |
|----------|----------|
| `GET /api/ws/makes` | `/makes/` |
| `GET /api/ws/models?make=` | `/models/` |
| `GET /api/ws/years?make=&model=` | `/years/` |
| `GET /api/ws/modifications?make=&model=&year=` | `/modifications/` |
| `GET /api/ws/search?make=&model=&year=&modification=&region=` | `/search/by_model/` |

Worker appends `user_key` and default regions for list calls. `search/by_model` uses a single `region` (default `jdm`).

## UI mapping
Make → Model → Year → Modification → show bolt pattern, PCD, centre bore, torque, tire sizes from `wheels[].front/rear.tire`.
