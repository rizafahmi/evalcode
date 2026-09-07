# Milestone 4 — Kanban pipeline

status: passed

## What's new in the app

- **The Pipeline home page is now a working Kanban board.** Five columns — Lead, Meeting, Proposal, Won, Lost — appear left to right, each showing every deal that currently sits on it.
- **One card per deal.** Every card shows the deal title, the contact it belongs to, and its value as real rupiah (`Rp 15.000.000`), and is clickable straight through to the deal page.
- **Drag a card to change its status.** Pick a card up and drop it on another column; the deal's pipeline column changes and the board, counts, and totals update immediately. Refresh the page and the deal is still on its new column.
- **Column totals in rupiah.** Each column header shows the sum of its cards' values (e.g. `Rp 35.000.000`) plus how many deals it holds, so a Won column's total reads like a small close figure.
- **A column that holds nothing says so** with a quiet "No deals" placeholder, and an account with no deals yet gets a hint on the board pointing back to Contacts (that's where deals are born).
- **Each account still only ever sees its own deals** on the board, and even a doctored drag of another account's deal id changes nothing.
- **Won and Lost get a tiny status marker** (a green dot for Won, a muted one for Lost) so the two end states read differently at a glance without new colors on cards.

## What was built

### Files, models, routes

No new migration, schema, or route was needed: the five seeded `pipeline_columns` (milestone 3) are the board's columns, deals already carry `pipeline_column_id`, and the board fills the existing authenticated `live "/" → PipelineLive` route.

- **Context** — `lib/alur/deals.ex` (`Alur.Deals`):
  - `list_deals/1` — account-wide fetch of every deal owned by `account`, newest first, with `contact` and `pipeline_column` preloaded (the board queries it once and groups by column). This is the seam milestone 8's account-scoped `GET /api/deals` builds on.
  - `get_pipeline_column/1` — lookup of one of the fixed seeded columns by id.
  - `move_deal/3` — `move_deal(account, deal_id, pipeline_column_id)`: resolves the deal account-scoped (unknown or another account's deal → `{:error, :not_found}`), resolves the target column, and updates only the column through the same changeset path the deal-edit page uses. Returns `{:ok, deal}` / `{:error, :not_found}` / `{:error, changeset}`. This is deliberately **the single choke point for changing a deal's column**, so milestone 5 can attach move logging here (and milestone 8's `PATCH /api/deals/:id` will call the same function).
- **LiveView** — `lib/alur_web/live/pipeline_live.ex` (`AlurWeb.PipelineLive`) grew from the milestone-1 placeholder into the board:
  - `mount/3` builds the board: `list_pipeline_columns/0` in board order × `list_deals/1` grouped by `pipeline_column_id`, producing a list of `%{column, deals, count, total}` where `total` is the integer sum of the column's card amounts.
  - `handle_event("move_deal", %{"deal_id" => …, "column_id" => …}, socket)` calls `Deals.move_deal/3` and re-assigns the board on success; on `:not_found` it simply does nothing (no crash, no state change), so foreign deal ids can never be dragged into the account.
  - The template renders the board (five equal, horizontally scrollable columns with count chip + rupiah total headers, draggable card links showing title / contact / rupiah value, "No deals" placeholders, and a Contacts hint when the pipeline is empty) plus a **colocated `.KanbanBoard` hook** (`<script :type={Phoenix.LiveView.ColocatedHook}>`) that turns HTML5 drag & drop into `move_deal` server events.
- **Client hook** — colocated JS inside `pipeline_live.ex` (compiled into the app.js bundle via the existing `phoenix-colocated` manifest; the tag engine rewrites `phx-hook=".KanbanBoard"` to the module-qualified `AlurWeb.PipelineLive.KanbanBoard`): delegated `dragstart`/`dragend`/`dragover`/`dragenter`/`dragleave`/`drop` listeners on `#pipeline-board`. `dragstart` records the card's deal id (and sets `text/plain` so Firefox actually drags); the column under the cursor is highlighted while over a column; `drop` pushes `move_deal` with the deal and target column ids. Drag state is always cleared on `drop`/`dragend`.
- **CSS** — `assets/css/app.css`: two small rules for classes the hook toggles at runtime (not Tailwind utilities, so they can't be generated): `.is-dragging { opacity: .45 }` (the card being dragged) and `.kanban-drop-target` (green-tinted border/background on the column a drag is hovering over), using existing Depot tokens (`--color-led-green`, `--color-fern-ground`).

### Tests (67 total, all green via `mix test`; was 58)

- `test/alur/deals_test.exs` (+6, `async: false`) — new `describe "list_deals/1"` (account-scoped, newest first across columns, contact + column preloaded, other accounts' deals never included) and `describe "move_deal/3"` (moves a deal and keeps owner + anchor, persists; moves to Won and Lost; refuses unknown deals, foreign accounts' deals, and unknown target columns, leaving the deal untouched).
- `test/alur_web/features/pipeline_test.exs` (new file, 3 PhoenixTest flows, `async: false`):
  1. Existing deals appear on the board in the right columns with the five headers rendered Lead → Lost in order; every card shows title, contact name, and rupiah value; column totals match the cards (`Rp 35.000.000`, `Rp 10.000.000`, empty columns `Rp 0`). "Dropping" a card is emulated through PhoenixTest's `unwrap` + `LiveViewTest.render_hook/3` firing the exact `move_deal` event the drag hook pushes: the card re-renders under Meeting, totals update, a `reload_page` keeps it there, and clicking the card opens the deal page (`assert_path("/deals/:id")`).
  2. Account isolation on the board: the second account sees only its own deals and totals; a `move_deal` event carrying the first account's deal id changes nothing, and the foreign deal is still on its original column afterwards.
  3. A fresh account sees the five empty columns (one "No deals" placeholder each) plus the create-a-deal hint.
- All 58 pre-existing tests pass unchanged (the shell tests that land on `/` still see the `Deal pipeline` heading).

## Decisions and deviations (not in the PRD)

1. **Drag & drop is HTML5 DnD handled by a colocated LiveView hook that pushes a `move_deal` event** — there is no LiveView-native board DnD (the framework's `phx-drop-target` is file-upload only), and this repo standardizes on colocated hooks (they are already wired into `assets/js/app.js`). The server never needs to know the drag happened; it only handles the drop event, which is exactly what milestone 8's `PATCH` semantics will mirror.
2. **The whole card is one draggable `<.link navigate>` to the deal page.** Browsers suppress the click after a real drag, so dragging never navigates and clicking anywhere on the card opens the deal — satisfying "click a card to open the deal" without a nested/hidden link.
3. **`move_deal/3` is the one place a deal's column changes from the board** (and later from the API). The existing deal-edit page still goes through `update_deal/2` directly; milestone 5 will route or wrap both so one place can log moves, per the milestone-3 handoff note.
4. **Cards within a column are newest first**, matching how milestone 3 orders deal lists elsewhere (the PRD does not prescribe intra-column order).
5. **Column markers**: Won gets the small signal-green dot and Lost a muted dot; the other three use neutral iron. Signal green is used only as that tiny status indicator, never as a fill for cards/buttons — CTA discipline is preserved, and milestone 3's "per-column colors can wait for the board" note is honored without adding card colors (still out of scope for this milestone).
6. **Empty pipeline UX**: columns always render (they are data, after all) with a per-column "No deals" placeholder; an account with zero deals additionally sees a hint strip linking to Contacts, since deals can only be created there.
7. **Testing drag**: PhoenixTest has no JS engine, so the feature tests exercise the exact server event the drop sends via `render_hook`, plus context tests for `move_deal` itself; the browser side (hook wiring, draggable attributes, drop highlighting) is verified by inspecting the rendered page, the compiled `app.js` bundle, and the served CSS.
8. **CSS state classes** (`.is-dragging`, `.kanban-drop-target`) are authored in `app.css` rather than as Tailwind utilities because they are added/removed by JS at runtime and would never appear in source for the scanner to generate.

## Notes for the next milestone

- Milestone 5 (activity log) should log moves from one place: `Deals.move_deal/3` is ready as that choke point for board drags (and will be for the milestone-8 API), but the deal-page column select currently updates through `update_deal/2` — milestone 5 should also make deal-page column changes log (e.g. detect a column change there, or route those edits through `move_deal`).
- Deals are still created only from contacts; a board-based "new deal" entry was not added (not requested; milestone 3 fixed creation to contacts).
- The board groups `list_deals/1` by column in the LiveView; milestone 8's Vue board will need the same account-scoped list (or `GET /api/pipeline` optional board aggregate) — `list_deals/1` and `list_pipeline_columns/0` are the existing seams.
- Column totals sum the integer `amount` and reuse `Deals.format_idr/1`, so milestone 8 can compute the same numbers client-side or keep trusting these.
- The "Won/Lost" markers introduced here are purely presentational (no data changes); the activity log milestone must not depend on them.

## Gate used

`mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix ex_dna --max-clones 0`, `mix reach.check --arch --smells`, and the full `mix test` (67 tests, 0 failures) — all clean/green. `mix assets.build` (Tailwind + esbuild) succeeds and the compiled `app.js` contains the `KanbanBoard` hook while `app.css` contains the drag-state rules.

Live HTTP checks against `mix phx.server` (port 4031): logged-out `GET /` and `GET /deals/:id` both 302 to `/accounts/log-in`; logging in through the real form lands on `/`; the signed-in board HTML shows the `Deal pipeline` heading, five columns in Lead → Lost order, `pipeline-column-*` ids, per-column totals incl. `Rp 35.000.000`, card text (`Website redesign`, `Sari Wijaya`, `Rp 15.000.000`), and the compiled `phx-hook="AlurWeb.PipelineLive.KanbanBoard"` attribute; `GET /deals/:id` renders the deal page. The seeded check data was removed afterwards.

No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
