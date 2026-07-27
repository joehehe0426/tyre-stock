# AGENTS.md — tyre-stock

呔妹輪胎庫存：Flutter **Web** app（PIN 鎖、本機 `SharedPreferences` 庫存、XLSX／Google Sheet 匯入、配對查詢）。

Live site: https://joehehe0426.github.io/tyre-stock/  
Repo: https://github.com/joehehe0426/tyre-stock

## Commands

Flutter SDK on this machine: `C:\flutter\bin\flutter.bat`（若不在 PATH，用完整路徑）。

| Action | Command |
|--------|---------|
| Deps | `flutter pub get` |
| Analyze | `flutter analyze` |
| Run web (local) | `flutter run -d chrome` |
| Build for GitHub Pages | `flutter build web --base-href /tyre-stock/` |

## Deploy landmines（必讀）

1. **推 `master` 不會更新線上站。** GitHub Pages 來源是 **`gh-pages` 分支**（靜態 `build/web` 產物），不是 `master`。
2. 部署流程：先 `flutter build web --base-href /tyre-stock/`，再把 `build/web/*` 複製到 `gh-pages` worktree 後 commit + push。`--base-href` 必須是 `/tyre-stock/`，否則資源 404。
3. 使用者更新後需 **Ctrl+F5**；本機庫存在瀏覽器 `SharedPreferences`（key `d`），壞快取時用 UI「清除本機庫存」。

## Code landmines

- **不要加回 `excel` package。** 公式欄（Brand `=PROPER(...)`）會 null-check crash。用 `lib/xlsx_reader.dart`（ZIP+XML）。
- Brand 若是公式／空值：從 Description 推品牌；保留公式的 cached 文字值若有。
- 尺寸解析支援：`245/40/18`、`255/55/R19`、空白、`/` 前綴、`C` 後綴等（`_parseSize`）。
- **重複列合併**：相同 key = brand + width + aspect + rim + pattern + year（不分大小寫）→ `_upsertTyre`／`_mergeAllDuplicates`，數量相加。新增／匯入／啟動都要走這條路，勿直接 `_all.add` 重複規格。
- 啟動時 `_isValidTyre` 會丟掉像 minified JS 這類污染快取；不要拿掉這層防護。
- UI／SnackBar 文案用**繁體中文**。
- 預設 PIN：`250183418`（`SharedPreferences` key `pin`／`authed`；舊預設 `tyre888` 會自動遷移）。

## Excel 欄位慣例

實際 `stock.xlsx`：Size, Brand（常為公式）, Description, Year, Price。無庫存欄時預設 `st = 1`。只支援 `.xlsx`，不支援舊 `.xls`。

## Branches

- `master` — 原始碼
- `gh-pages` — 線上站建置產物（勿當一般功能分支改）

`auth-worker.js` + `wrangler.toml` 是 Cloudflare 自訂網域／auth 相關；與 GitHub Pages 主站分開，改動前先確認用途。

## Scope tips

- 幾乎所有 UI／庫存邏輯在 `lib/main.dart`；XLSX 解析在 `lib/xlsx_reader.dart`。
- 配對：本機 `assets/fitment_data.json`；線上經 Cloudflare `/api/ws/*` 代理 Wheel Size API（Secret `WHEEL_SIZE_USER_KEY`）。香港無 `hkdm`，預設 region：`jdm`/`eudm`/`sam`。
- 未要求時不要 commit；部署 `gh-pages` 需明確推送意圖（遠端可能需先 fetch 再推，避免 non-fast-forward）。
