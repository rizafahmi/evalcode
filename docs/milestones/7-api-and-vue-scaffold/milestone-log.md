# Milestone 7 — API health and Vue scaffold

status: passed

## What's new in the app

- **There is a JSON API health check.** `GET /api/health` answers from any client — logged in or not — with `200` and exactly `{"status":"ok"}`.
- **A Vue application now runs inside Phoenix at `/app`.** Sign in and open `/app` (it is not linked from the nav — you type the URL): an empty mount node is served by Phoenix and Vue 3 boots on it (the node gets Vue's `data-v-app` attribute). The scaffold asks the new health endpoint and shows **API health — ok** when the JSON surface is reachable.
- **The toolchain for milestone 8 is in place.** Vue 3 + TypeScript build with Vite, tested with Vitest, all living inside `assets/`. A Vite watcher runs under `mix phx.server` and Phoenix serves the built bundle — no separate frontend server.
- **Nothing else changed.** The LiveView Pipeline at `/` (and Contacts / deal pages / activity / To-dos) is untouched, there is no fourth nav item, and no `/api/deals` yet.

## What was built

### Routes

- `GET /api/health` → `AlurWeb.HealthController` — **unauthenticated**, `pipe_through :api`, returns `json(conn, %{status: "ok"})`. Body is exactly the PRD-locked object, no extra fields.
- `GET /app` → `AlurWeb.AppController` — a plain **controller** page `pipe_through [:browser, :require_authenticated_account]`, declared in its own scope **outside** the `:authenticated` live_session (per `docs/decisions.md`). Logged-out visitors get the standard 302 to `/accounts/log-in` (`require_authenticated_account` also remembers the return path, so you land back on `/app` after signing in).

### Elixir files

- `lib/alur_web/controllers/health_controller.ex` — `AlurWeb.HealthController.index/2`.
- `lib/alur_web/controllers/app_controller.ex` — `AlurWeb.AppController.index/2` renders `:index` with `page_title: "App workspace"`.
- `lib/alur_web/controllers/app_html.ex` + `app_html/index.html.heex` — the signed-in page shell (`<Layouts.app flash={@flash} current_scope={@current_scope}>`, so the standard Alur header/footer render with `current_scope`), a Depot-styled header, the **empty mount node** `<div id="app" aria-label="Vue application">`, and `<script defer src={~p"/assets/vue/app.js"}>` at the end of the body. The script tag lives on this controller template only — never in a LiveView render.
- `lib/alur_web/router.ex` — the two new scopes above.
- `config/dev.exs` — third entry in `Endpoint.watchers` running the Vite build-watch (`npm run dev` → `vite build --watch --mode development`) from `assets/`; the existing `live_reload` patterns already cover `priv/static/**/*.js`, so a Vue edit rebuilds and the browser reloads like any Phoenix asset.
- `mix.exs` aliases — `assets.setup` now also runs `npm install --prefix assets`; `assets.build` and `assets.deploy` run the Vite production build before `phx.digest`; `precommit` now also runs the Vitest suite (`cmd npm run test --prefix assets`) so the Vue tests sit in the same done-gate as formatter/credo.

### Vue + Vite + Vitest (all inside `assets/`)

- `assets/package.json` (+ `package-lock.json`) — `vue@^3.5`; dev: `vite`, `vitest`, `@vitejs/plugin-vue`, `@vue/test-utils`, `jsdom`, `typescript`, `@types/node`. Scripts: `dev` (`vite build --watch --mode development`), `build` (`vite build`), `test` (`vitest run`).
- `assets/vite.config.ts` — builds `assets/vue/main.ts` straight into Phoenix's `priv/static/assets/vue/app.js` (stable name, `emptyOutDir`, dev-mode sourcemaps, `base: "/assets/vue/"`). Root anchored to `assets/` so the outDir is repo-relative wherever npm runs.
- `assets/vue/main.ts` — `createApp(App).mount("#app")`; Vue marks the node `data-v-app`.
- `assets/vue/App.vue` — milestone-7 stub: on mount it `fetch`es `/api/health` and renders a Depot terminal-style card (**API health · ok** / checking… / unreachable) with a `data-health` attribute for tests.
- `assets/vue/App.test.ts` (3 tests), `assets/vitest.config.ts` (jsdom) — boots the real entry on a `#app` node and asserts `data-v-app` + `ok`; covers the unreachable state; asserts the fetch URL/accept header.
- `assets/tsconfig.json` — rewritten for the node_modules era (no more `../deps/*` mapping), includes `js/**/*` + `vue/**/*` + the two configs, `types: ["node", "vite/client"]`.
- `assets/css/app.css` — added `@source "../vue";` so Tailwind scans utility classes used inside `.vue` templates.
- `assets/js/app.js` + `assets/vendor/topbar.cjs` — see deviation 3.

### Tests

- `test/alur_web/controllers/health_controller_test.exs` — `GET /api/health` returns `200` with exactly `%{"status" => "ok"}`.
- `test/alur_web/controllers/app_controller_test.exs` — logged-out `/app` 302s to `/accounts/log-in`; signed-in `/app` is `200` HTML containing the empty `id="app"` mount node, the `src="/assets/vue/app.js"` entry, the page heading, and the signed-in chrome.
- Vitest (3, in `assets/vue/App.test.ts`) as above.
- Full ExUnit run: **109 tests, 0 failures** (was 106).

## Decisions and deviations (not in the PRD)

1. **Vite writes into Phoenix's static dir instead of running a dev server with a proxy.** Of the two options the milestone/decisions file allow ("import the Vue entry from `app.js`", or "a Vite watcher in `config/dev.exs` plus a layout script"), I chose the watcher + layout script: `vite build --watch` emits `priv/static/assets/vue/app.js`, which Phoenix serves in every environment (dev watcher, `mix assets.deploy` for prod, where `phx.digest` fingerprints it like any other asset). No second server, no CORS, one OTP app — matching the locked stack.
2. **No per-page CSS bundle from Vite.** The `/app` markup and the Vue stub reuse the global Tailwind CSS that every page already loads (`Layouts.app` chrome), and `assets/css/app.css` now scans `assets/vue`. The Vue entry therefore emits only `app.js`, and the controller template needs no extra `<link>`.
3. **Adding `assets/package.json` with `"type": "module"` changed how esbuild parses `.js` files, breaking the Phoenix asset bundle.** esbuild now treats every `.js` under `assets/` as ESM, and `vendor/topbar.js` is a CommonJS/UMD file with no ESM exports — `js/app.js`'s `import topbar from "../vendor/topbar"` failed with *"No matching export … for import 'default'"*, which silently stopped the esbuild watcher from producing `app.js`. Fix: renamed the vendor file to `topbar.cjs` (esbuild always parses `.cjs` as CommonJS) and updated the import. This is a rename of a scaffold file, called out because it touches pre-existing repo content; the esbuild bundle rebuilds cleanly now.
4. **Phoenix watcher entries key on the executable.** A watcher value like `{command, args, opts}` is interpreted as an MFA (module must be an atom), and a plain-list watcher uses the **keyword key** as the command to run. The dev watcher is therefore the explicit pair `{"npm", ["run", "dev", cd: …]}`, written as a plain tuple list (`{:esbuild, …}, {:tailwind, …}, {"npm", …}`) because string keys can't use the `key:` keyword-list sugar after atom keys.
5. **Versions.** `npm install` resolved current stable majors at build time: vue 3.5, vite 8, vitest 5, @vitejs/plugin-vue 6, jsdom 30, typescript 7 — pinned in `assets/package-lock.json` for reproducibility. No manual version pinning was needed; everything interoperated out of the box.
6. **`/app` uses the standard `Layouts.app` signed-in chrome** (like the log-in/register controller pages do), because the PRD wants no extra nav item but the page should still feel like the app — the nav shown is the unchanged Pipeline/Contacts/To-dos set.
7. **`precommit` now runs Vitest.** The decisions file says Vitest sits in the same done-gate as formatter/credo from milestone 7; wiring it into the existing `precommit` alias means milestone 8's gate can't silently skip the Vue tests.
8. **Health JSON is produced with `json/2`** (Phoenix + Jason) — the response body is byte-for-byte `{"status":"ok"}`, asserted in the ConnCase test.

## Notes for the next milestone

- Milestone 8 grows `assets/vue/App.vue` (replace the health stub) into the Kanban board and adds the `/api/deals*` endpoints. The plumbing is ready: `/app` is a controller page whose JS is served by Phoenix, the browser session cookie is the shared auth token (same-origin `fetch` sends it automatically), `AppController`/`AppHTML` stay, and `Alur.Deals.move_deal/3` remains the single move-logging choke point the `PATCH` must call.
- Vue dev workflow: `mix phx.server` starts the Vite build-watch automatically; `npm test` (or `mix precommit`) runs Vitest; `mix assets.build`/`assets.deploy` produce the production bundle.
- The `data-health` attribute and `data-v-app` marker on `#app` are handy hooks for milestone-8 browser checks.
- Tailwind now scans `assets/vue`, so Vue templates can use Depot utility classes directly; keep bespoke (non-utility) CSS in `app.css` like the milestone-4 Kanban classes.
- The `/app` page is only reachable by URL (no nav item, per PRD) — revisit copy ("Vue workspace") when the real board lands.

## Verification

- `GET /api/health` unauthenticated → `200` `{"status":"ok"}` (curl against `mix phx.server`, plus the ConnCase test).
- Signed-in `GET /app` → `200` controller HTML with the empty mount node and the Vue entry script (curl with a real registered session, plus the ConnCase test); logged-out → 302 to `/accounts/log-in`.
- **Browser check (real engine):** headless Chrome Canary via CDP registered an account, opened `/app`, and waited — result `{"mounted": true, "dataVApp": "", "health": "ok", "text": "API health ok …"}`. The same browser session also loaded `/` (LiveView Pipeline) with `liveSocket` connected, confirming the esbuild app bundle still works after the toolchain change.
- Gate: `mix precommit` (compile `--warnings-as-errors`, `deps.unlock --unused`, `format --check-formatted`, `mix test` **109/0**, `npm run test`/Vitest **3/0** via the alias, `credo --strict` clean, dialyzer 0, `ex_dna --max-clones 0`, `reach.check --arch --smells`) — **exit 0**.

No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
