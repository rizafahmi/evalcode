# Milestone 3 — Deals

status: passed

## What's new in the app

- **Start a deal from a contact**: every contact page now has a Deals panel with a **New deal** entry point, so an opportunity is always created for the person behind it (title, IDR value, starting pipeline column, optional notes).
- **Deals show real rupiah everywhere**: values are entered in IDR and displayed as `Rp 15.000.000` (Indonesian dot grouping) on the contact's list, the deal page, and the forms.
- **A deal page per opportunity**: shows the title, the rupiah value, the contact it belongs to, its pipeline column, and notes — with an **Edit deal** action and a confirmed **Delete**.
- **Move a deal along the pipeline today**: the pipeline column is a field on the deal page, so you can change a deal from Lead to Meeting (and so on) even though the Kanban board arrives in a later milestone.
- **The five columns already exist as data**: Lead, Meeting, Proposal, Won, Lost are seeded in order and shown as a status chip on deals; new deals start on Lead unless you pick another column.
- **The contact's page lists its deals**: newest deal first, with the rupiah value and column for each, plus a one-click path into the deal.
- Deals are private to your account: another account never sees your deals, and directly typing in someone else's deal or their contact's new-deal web address only bounces you back to your own Contacts list.
- Deleting a contact also removes its deals — no orphaned opportunities left behind.

## What was built

### Files, models, routes

- **Migrations**
  - `priv/repo/migrations/20250101000003_create_pipeline_columns.exs` — creates `pipeline_columns` (`id` binary_id PK, `name`, `order`, timestamps; unique index on `name` and on `order`) and **seeds the five fixed columns** (Lead, Meeting, Proposal, Won, Lost) inside the migration via `repo().insert_all` with a tiny private seed schema, so every environment — dev, test, prod — gets them without running `seeds.exs`. `up`/`down` are explicit because the data insert is not reversible automatically.
  - `priv/repo/migrations/20250101000004_create_deals.exs` — creates `deals`: `account_id` → `accounts` (`on_delete: :delete_all`), `contact_id` → `contacts` (`on_delete: :delete_all`), `pipeline_column_id` → `pipeline_columns` (`on_delete: :restrict`), plus `title` (required), `amount` (integer, required), `notes` (text, optional) and timestamps; indexes on all three foreign keys.
- **Schemas** — `lib/alur/deals/deal.ex` (`Alur.Deals.Deal`) and `lib/alur/deals/pipeline_column.ex` (`Alur.Deals.PipelineColumn`), binary_id keys, `belongs_to :account/:contact/:pipeline_column` on Deal.
- **Context** — `lib/alur/deals.ex` (`Alur.Deals`): `list_pipeline_columns/0` (ordered Lead → Lost), `list_contact_deals/2` (account-scoped, newest first, contact + column preloaded), `get_deal/2` (account-scoped, preloaded; `nil` when unknown or foreign), `create_deal/3` (`account`, account-scoped `contact`, attrs), `update_deal/2`, `delete_deal/1`, `change_deal/2`, and `format_idr/1` (`Rp 15.000.000` grouping; `—` for a missing value). The Deal changeset casts **only** `title`, `amount`, `notes`, `pipeline_column_id` — `account_id` and `contact_id` are stamped by the context and can never be changed through a form. Validation: `title`/`amount`/`contact`/column required, amount ≥ 0, title ≤ 200 chars.
- **Routes** (`lib/alur_web/router.ex`, inside the existing `live_session :authenticated`): `live "/contacts/:contact_id/deals/new"` → `DealsLive :new`, `live "/deals/:id"` → `:show`, `live "/deals/:id/edit"` → `:edit`. No nav item (deals live on contacts until the board milestone).
- **LiveView** — `lib/alur_web/live/deals_live.ex` (`AlurWeb.DealsLive`), one module for the three routes: the create form is anchored to the contact from the path (a contact that is missing or belongs to another account bounces to `/contacts` with a notice), the deal page shows title / rupiah value / contact link / pipeline column chip / notes with edit and confirmed delete, and the edit form covers title, value, column (select of the five seeded columns) and notes with the contact fixed. Save/create redirect to the deal page; delete returns to the deal's contact page.
- **Contact page** — `lib/alur_web/live/contacts_live.ex` `:show` now loads the contact's deals and renders a Deals panel (count header, ghost-outline **New deal** entry, newest-first table of title / `Rp` value / column chip, empty state) replacing the milestone-2 "deals arrive next milestone" teaser.

### Tests (58 total, all green via `mix test`; was 40)

- `test/alur/deals_test.exs` (15, `async: false`) — pipeline columns seeded in order; create requires title/amount/column while notes stay optional; negative amount rejected; smuggled `account_id`/`contact_id` in attrs are ignored; `list_contact_deals` is account-scoped and newest-first; deals preload contact and column; `get_deal` returns `nil` for foreign accounts and unknown ids; update edits title/value/column/notes but never the owner or anchor and still validates; delete removes the deal; **deleting a contact cascades to its deals** (FK `on_delete: :delete_all` is enforced by ecto_sqlite3's default `foreign_keys: :on`); `format_idr` grouping incl. `Rp 0`, `Rp 1.000`, `Rp 1.000.000.000`, and `—` for `nil`.
- `test/alur_web/features/deals_test.exs` (3, PhoenixTest) — the full lifecycle from the UI: contact page empty deals panel → New deal → create with value/notes (default column Lead) → deal page shows `Rp 15.000.000`, column and notes → back to the contact whose list shows the deal → open → edit value to `Rp 20.000.000` and column to Meeting → delete → empty panel again; cross-account isolation (own contact shows no foreign deals; directly opening another account's deal or new-deal URL bounces with "Deal not found."/"Contact not found."); form validation (missing title/value, negative amount).
- All 40 pre-existing tests still pass unchanged.

## Decisions and deviations (not in the PRD)

1. **Deals are created anchored to a contact, and the contact never changes.** The create route lives under the contact (`/contacts/:contact_id/deals/new`) and the contact must belong to the signed-in account; the edit form has no contact field. This matches the PRD's "create a deal from a contact … contact is required", keeps ownership airtight (a deal can never be anchored to another account's contact), and the PRD never asks to re-home a deal — milestone 8's API only ever moves `pipeline_column_id`.
2. **Amount is a whole number of rupiah stored as an integer** (e.g. `15000000`), typed on a `number` input. Zero is allowed (`≥ 0`); negative values are rejected. The PRD's data model lists no amount precision/currency rules beyond IDR, so whole-IDR was the simplest correct option.
3. **Pipeline columns are seeded inside the migration**, not in `priv/repo/seeds.exs`, so tests (which only ever run migrations) and fresh environments get the five columns automatically. `on_delete: :restrict` on the deal→column FK guards against ever dropping a column that still has deals.
4. **Deleting a contact deletes its deals via the DB cascade** (`on_delete: :delete_all`, already enforced since ecto_sqlite3 turns foreign keys on by default). Without it, deleting a contact would leave orphaned deals pointing at nothing, crashing their deal pages.
5. **Missing/foreign deal or contact bounces to `/contacts` with a flash** ("Deal not found." / "Contact not found."), the same no-404, no-existence-leak convention milestone 2 established — the visitor cannot tell whether a record exists but belongs to someone else.
6. **Delete lives on the deal page** (confirmed), returning to the deal's contact page, mirroring where milestone 2 put contact delete; done-when only requires delete to exist.
7. **One LiveView module for the three deal routes** (single-module-per-section style from milestones 1–2); deal page shows an explicit "Deals" eyebrow and neutral column chips.
8. **Rupiah formatting lives in the context** (`Alur.Deals.format_idr/1`) rather than duplicated in templates, so milestone 4's board and later views use the same display everywhere.
9. **CTA discipline kept**: "New deal" on the contact panel is a ghost/outline button because the page's one signal-green CTA stays "Edit contact"; on the deal page the single green CTA is "Edit deal". Column chips are neutral (no per-column colors yet — that can wait for the board).
10. **Value defaults**: new deals preselect Lead as the starting column; a contact's deal list is newest first.

## Notes for the next milestone

- Milestone 4 (Kanban pipeline) will need an **account-wide** deals fetch (e.g. `Deals.list_deals(account)` or per-column query) — the context currently only lists deals by contact (`list_contact_deals/2`). `list_pipeline_columns/0` and `format_idr/1` are already the seams the board needs; cards want `contact` and `pipeline_column` preloaded, exactly like `get_deal/2`.
- Column moves currently happen only through `update_deal/2` on the edit page. The board's drag handler should reuse the same changeset/update path so milestone 5 can log moves from one place.
- Column chips and "Won/Lost" emphasis are deliberately unstyled-for-now; milestone 4 can introduce per-column colors/totals without touching data.
- Column totals in milestone 4 should sum the integer `amount` and format with the same `format_idr`.
- The contact-delete → deal-cascade behavior is worth an explicit note in the contacts docs/tests if contacts ever grow more children (activity, next actions in milestones 5–6).
- SQLite async gotcha still applies: every DB-writing test module is `async: false`.

## Gate used

`mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix ex_dna --max-clones 0`, `mix reach.check --arch --smells`, and the full `mix test` (58 tests, 0 failures) — all clean/green. Live HTTP checks against `mix phx.server`: logged-out `/contacts`, `/deals/*`, and `/contacts/*/deals/new` all 302 to log-in; registering through the real form signs in; the signed-in contact page lists a context-created deal with `Rp 15.000.000` and its column; the deal page, edit prefill, new-deal Lead default, and missing-deal redirect all verified.

No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
