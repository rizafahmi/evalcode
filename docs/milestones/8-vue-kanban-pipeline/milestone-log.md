# Milestone 8 — Vue Kanban over REST

status: passed

## What's new in the app

- **A second Kanban now runs at `/app`, this one rendered by Vue and fed by the JSON API.** Sign in and open `/app` by URL (it still is not in the nav — the LiveView Pipeline at `/` stays the home page): five columns — Lead, Meeting, Proposal, Won, Lost — show the same deals as the home board, each card with the deal title, its contact, and the value as rupiah (`Rp 15.000.000`), with a rupiah total and deal count under every column header.
- **Dragging works over REST.** Pick a card up and drop it on another column: the page issues `PATCH /api/deals/:id` with the target `pipeline_column_id`, the move is saved through the same `move_deal` path the LiveView board uses, and the card re-renders under its new column with totals recalculated. Refresh the page and the card stays where you dropped it.
- **The move still lands in the deal's activity log.** Because the `PATCH` goes through `Alur.Deals.move_deal/3`, a drag on the Vue board writes the same `Moved from … to …` line a drag on the LiveView board writes — open the deal afterwards and the history is there.
- **Clicking a card opens the deal.** Every card is a link through to the existing LiveView deal page (`/deals/:id`), exactly like the home board.
- **The board is account-scoped over the session cookie.** The Vue fetches authenticate with the same browser session the page was loaded with; a logged-out request to any deal endpoint gets `401`, and no account can list, read, or move another account's deals (they answer `404`).
- **The JSON surface is real.** `GET /api/deals`, `GET /api/deals/:id`, and `PATCH /api/deals/:id` join the health endpoint under `/api`, and `GET /api/pipeline` returns the board aggregate (columns in order with their ids, plus the account's deals) so the Vue board renders from a single request.
- **Nothing else changed.** Contacts, deal pages, activity, to-dos, and the LiveView Pipeline at `/` are untouched, and there is still no fourth nav item.

## What was built

### Routes (`lib/alur_web/router.ex`)

- New `:api_authenticated` pipeline — `:accepts json`, `:fetch_session`, `:fetch_current_scope`, `:require_api_account` — for account-scoped JSON.
- A second `/api` scope (outside the unauthenticated health scope) with:
  - `GET /api/pipeline` → `Api.DealsController.pipeline`
  - `GET /api/deals` → `Api.DealsController.index`
  - `GET /api/deals/:id` → `Api.DealsController.show`
  - `PATCH /api/deals/:id` → `Api.DealsController.update`

### Auth (`lib/alur_web/account_auth.ex`)

- `require_api_account/2` — API counterpart of the browser `require_authenticated_account`: halts with `401 {"errors":{"detail":"You must log in to access this resource."}}` instead of redirecting. Sessions are the same browser cookie the HTML pages use, so the Vue app needs no token and there is no CORS.

### Controller (`lib/alur_web/controllers/api/deals_controller.ex`)

- `AlurWeb.Api.DealsController` (new `api/` folder), every action reading the account from `conn.assigns.current_scope`:
  - `index/2` — `list_deals/1` → `%{"deals" => [deal_json]}`.
  - `show/2` — `get_deal/2` → `%{"deal" => deal_json}` or `404`.
  - `update/2` — reads `params["pipeline_column_id"]` and calls the existing **`Alur.Deals.move_deal/3`** (activity-log move lines keep firing); `200 %{"deal" => ...}` on success, `404` for a foreign/unknown deal or unknown column, `422` when the body omits `pipeline_column_id`.
  - `pipeline/2` — the board aggregate: `list_pipeline_columns/0` mapped to `%{id, name, order}` plus `list_deals/1` mapped to deal JSON.
- JSON error convention matches Phoenix's (`%{"errors" => %{"detail" => …}}`).

### Deal JSON shape

Each deal is served as `%{id, title, amount, pipeline_column_id, contact: %{id, name}}` — the fields the milestone-4-style card needs (title, contact, IDR value) plus the column the board groups by. `/api/deals` only returns deals; `/api/pipeline` also returns the columns with their ids.

### Vue + Vitest (`assets/vue/`)

- `types.ts` — `PipelineColumn`, `DealContact`, `Deal`, `PipelineData` mirroring the JSON contract.
- `api.ts` — `fetchPipeline/0` (`GET /api/pipeline`) and `moveDeal/2` (`PATCH /api/deals/:id`, JSON body), both same-origin `fetch` with `credentials: "same-origin"`, JSON accept; non-2xx throws so the board can show its error state.
- `formatIdr.ts` (+ `formatIdr.test.ts`, 2 tests) — mirrors `Alur.Deals.format_idr/1` (`Rp 15.000.000` dot grouping; `—` for a missing amount) so Vue totals/cards read identically to LiveView.
- `App.vue` — the milestone-7 health stub is replaced by the board: loads `/api/pipeline` on mount (loading → ready/error states with a Try again button), renders the five columns Lead → Lost with count chips, rupiah totals, draggable card links to `/deals/:id`, "No deals" placeholders, the empty-pipeline hint linking to Contacts, and a per-move error banner. Column totals are derived from the card amounts.
- `App.test.ts` (6 tests) — boots the real entry on `#app` (asserts Vue's `data-v-app`), asserts column order/cards/rupiah totals/click-through hrefs and the pipeline fetch's URL/credentials/accept header, and drives synthetic `dragstart`/`drop` events asserting the exact `PATCH` (URL, method, JSON body, headers), the re-render into Meeting with recomputed totals, that a same-column drop issues **no** PATCH, that a failed move PATCH keeps the card put and shows the error, and the load-error state.

### Page shell

- `lib/alur_web/controllers/app_html/index.html.heex` + `app_controller.ex` — copy now matches the real board ("Vue Kanban · REST" eyebrow, "Deal board" heading, drag-and-refresh description); `page_title` updated. Mount node and entry script unchanged.
- `test/alur_web/controllers/app_controller_test.exs` — heading assertion updated to "Deal board".

### Tests

- `test/alur_web/controllers/api/deals_controller_test.exs` (new, 13 tests) — real session-cookie sign-in through the HTML log-in form; covers 401 (list, show, patch, pipeline), the deals list contract (fields, newest-first, own account only), one-deal fetch, 404s (unknown and other account's), `PATCH` moving a deal **with the activity-log move line asserted**, same-column PATCH being a harmless 200, foreign-deal/unknown-column 404s that leave the deal alone, a 422 for a missing `pipeline_column_id`, and the pipeline aggregate (column order/ids plus deals, isolation).
- Full ExUnit run: **122 tests, 0 failures** (was 109). Vitest: **8 tests, 0 failures** (was 3).

## Decisions and deviations (not in the PRD)

1. **`GET /api/pipeline` returns the columns (with ids and order) *plus* the account's deals as a flat list, not per-column nested cards/totals.** The decisions file calls it an optional "board aggregate with column ids"; the Vue board needs the column ids `/api/deals` does not return, so this endpoint exists, and returning the columns and deals together means the board renders from exactly one authenticated fetch. Column totals are computed client-side from the card amounts (like the LiveView board computes them server-side), so totals match the cards by construction.
2. **Deal JSON carries more than the minimum the decisions file lists (`id`, `title`, `pipeline_column_id`).** Milestone 8's cards show title, contact, and the IDR value, and totals need amounts, so the JSON adds `amount` and `contact` (`id` + `name`) — the smallest set that renders the milestone-4 UX. `notes` and other fields are deliberately not exposed.
3. **New controllers live in a nested `AlurWeb.Api` namespace** (`lib/alur_web/controllers/api/deals_controller.ex`), while the milestone-7 `HealthController` stays where it was — the `/api` deal surface is distinct enough to warrant the namespace, and moving health would churn the existing log/test for no gain.
4. **`PATCH` uses a flat JSON body `{"pipeline_column_id": "…"}`** (not `{"deal": …}`), the simplest shape the PRD allows ("JSON body includes `pipeline_column_id`").
5. **The Vue board updates pessimistically:** the card only changes column after the `PATCH` answers `200`. Refresh persistence and totals therefore always reflect what the server stored, and dropping a card on its own column never fires a request (the server would write no activity line for it anyway). A failed move shows a dismissible error banner and the card stays put.
6. **Drag & drop is native HTML5 events handled in Vue**, mirroring the LiveView board's hook: `dragstart` records the deal id (and sets `text/plain` so Firefox drags), columns allow `dragover` only while dragging, and `drop` triggers the `PATCH`. The existing `.is-dragging` and `.kanban-drop-target` classes in `app.css` are reused for the drag affordances — they are runtime-toggled classes that Tailwind cannot generate, and the Vue board never coexists with the LiveView board in the same DOM.
7. **`/app` page copy updated** ("Deal board") since the milestone-7 stub ("reports the JSON API health") no longer describes the page; the mount-node/entry plumbing itself is unchanged.
8. **422 semantics:** a missing `pipeline_column_id` answers `422` with a field error; because `move_deal/3` pre-resolves the column, a changeset-level failure is effectively unreachable, so that branch answers a generic `422` detail instead of duplicating the test-support `errors_on` code (which `ex_dna` would flag as a clone).
9. **Controller tests sign in through the real HTML log-in form** (POST `/accounts/log-in`, session cookie kept) rather than registering accounts twice or minting session tokens directly, so the authorization path under test is exactly the one the Vue `fetch` calls ride.

## Notes for the next milestone

- The PRD's milestone list ends at 8; per the PRD's own note, the build-plan files under `docs/` (this PRD, `decisions.md`, `run-autonomous.md`, and the milestone folders) are expected to be deleted once the initial build-out ships — `docs/prd.html` explicitly says no code should read them. The Vue board and its `/api` surface are complete as specified.
- If the LiveView Pipeline and the Vue board are ever to share data instantly, both currently render from reads on mount/reload; there is no cross-page push yet (nothing in scope asked for one).
- The Vue app is still one entry (`app.js`); if `/app` grows beyond the board, splitting `App.vue` into column/card components is the natural next step.
- `formatIdr` (TS) and `Alur.Deals.format_idr/1` (Elixir) are now intentional duplicates; keep them in sync if rupiah formatting ever changes.

## Verification

- **ConnCase (13 new + full suite):** `mix test` → 122 tests, 0 failures.
- **Vitest:** 8 tests, 0 failures (`npm test` in `assets/`).
- **REST/HTTP against a live `mix phx.server` (dev, port 4000), real session cookies via the HTML log-in form — 19/19 passed:** logged-out `GET /api/deals`, `GET /api/pipeline`, and `PATCH /api/deals/:id` → `401`; signed-in `GET /app` → 200 HTML with the `id="app"` mount node and `/assets/vue/app.js` entry; `GET /api/pipeline` returns Lead → Lost in order; `GET /api/deals` returns exactly the account's three seeded deals with the card fields; `GET /api/deals/:id` 200/404; `PATCH` moved a deal Lead → Proposal, showed up in `/api/pipeline`, and moved it back; unknown column → 404; a second account saw only its own deals and got `404` reading/patching the first account's deal, `200` on its own.
- **Browser check (real engine — headless Chrome Canary via CDP):** logged in through the actual log-in form, opened `/app`, and confirmed Vue mounted (`data-v-app` present, `data-board data-state="ready"`); the five columns rendered Lead → Lost; the seeded deals sat in the right columns with totals matching (`Lead Rp 25.000.000/2`, `Meeting Rp 20.000.000/1`); a synthetic HTML5 drag of "Website redesign" Lead → Meeting produced a **real network `PATCH http://127.0.0.1:4000/api/deals/<id>` with body `{"pipeline_column_id":"…"}`** (captured via CDP `Network.requestWillBeSent`), the card re-rendered in Meeting, totals recomputed (`Lead Rp 10.000.000`, `Meeting Rp 35.000.000`); after a full page reload the card was still in Meeting with the same total; clicking the card navigated to `/deals/<id>` whose `h1` read "Website redesign"; and the nav still had no `/app` item (no fourth nav item).
- **Gate:** `mix precommit` (compile `--warnings-as-errors`, `deps.unlock --unused`, `format --check-formatted`, `mix test` 122/0, Vitest 8/0 via the alias, `credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`) — **exit 0, all clean**; `npm run typecheck` (tsc strict) clean; `npm run build` and `mix assets.build` produce the bundles, with `priv/static/assets/css/app.css` containing the board classes scanned from `assets/vue`.

No commit was made by this worker (the parent orchestrator commits each green milestone per the milestone workflow).
