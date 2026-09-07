# Milestone 5 — Activity log

status: passed

## What's new in the app

- **Every deal now opens with its history.** A new "Activity log" panel sits under the deal's details and shows the deal's timestamped history newest-first — the top line is always the most recent thing that happened.
- **A "Deal created" line appears automatically.** The moment a deal is created (from a contact), it gets its first log entry, so opening any deal shows where it started.
- **Moving a deal is logged everywhere it can happen.** Drop a card on another column of the pipeline board, or change the column on the deal's edit page — either way the log records exactly what moved, like `Moved from Lead to Meeting`, with the date and time.
- **You can write free-text notes into the log.** An "Add a note" box at the bottom of the panel lets you jot context (call summaries, quotes sent, pricing thoughts) and it appears immediately at the top of the log as `Note: …`.
- **Lines show the time in Indonesian time.** Every entry is stamped with the day and time in WIB (Asia/Jakarta), e.g. `12 Jan 2025, 21:05 WIB`, so "when did that happen" reads naturally for the app's Indonesian audience.
- **The log is write-only.** There is no way to edit or delete a line — it is a true history, and it dies with its deal (deleting a deal or a contact cleans up the lines too).
- **Logs stay private to your account.** A deal page (and so its log) is unreachable across accounts, exactly like every other deal screen.

## What was built

### Files, models, routes

No new route was needed: the activity log lives on the existing authenticated deal page (`live "/deals/:id" → DealsLive :show`), and the deal page is where milestone 6 will surface follow-up lines too.

- **Migration** — `priv/repo/migrations/20250101000005_create_activities.exs`: creates `activities` (`id` binary_id PK, `deal_id` → `deals` with `on_delete: :delete_all`, `description` text required) plus an index on `deal_id`. Timestamps are `:utc_datetime_usec` — microsecond precision so two lines written within the same second still order deterministically (the log is newest-first). Deleting a deal (or a contact, which cascades to its deals) removes the deal's lines via the DB cascade.
- **Schema** — `lib/alur/activities/activity.ex` (`Alur.Activities.Activity`): binary_id keys, `description`, `belongs_to :deal`, `utc_datetime_usec` timestamps. The changeset casts only `description` (`deal_id` is stamped by the context), requires both, and caps descriptions at 500 characters.
- **Context** — `lib/alur/activities.ex` (`Alur.Activities`):
  - `list_for_deal/1` — every line for a deal, newest first.
  - `log/2` — writes one immutable line for a deal (`{:ok, activity}` / `{:error, changeset}`). This is the **hook point** milestone 6's follow-up add/complete events (and manual notes) write through.
  - `format_when/1` — renders a line's timestamp as e.g. `12 Jan 2025, 21:05 WIB`.
  - `change_activity/2` — changeset helper.
- **Context changes** — `lib/alur/deals.ex` (`Alur.Deals`):
  - `create_deal/3` now writes the deal **and** its opening `Deal created` line in one `Repo.transaction`, so a deal never exists without its created line (same `{:ok, deal}` / `{:error, changeset}` contract as before).
  - `update_deal/2` detects when an update actually moves the deal onto a different pipeline column and writes the matching `Moved from X to Y` line (newest-first with the update's timestamp). Ecto only reports a column change when the value differs, so re-saving the same column — or dropping a card on the column it is already on — writes nothing. Column names resolve from the preloaded `pipeline_column` when present (deal pages and `move_deal/3` fetch through `get_deal/2`, which preloads) and fall back to the fixed columns otherwise.
  - `move_deal/3` is unchanged externally (still `{:ok, deal}` / `{:error, :not_found}` / `{:error, changeset}`) and funnels through the same `update_deal/2` path, so **board drags and deal-page column changes log from one choke point** — the milestone-4 handoff note is closed via the "detect the column change" option.
- **LiveView** — `lib/alur_web/live/deals_live.ex` (`AlurWeb.DealsLive`) `:show`:
  - Loads the deal's lines (`Alur.Activities.list_for_deal/1`) and a note form on mount; renders an "Activity log" panel (Depot graphite card with a count chip) under the Details card: each row is a mono `WIB` timestamp plus the description, newest first, with a per-deal empty state ("No log entries yet.") for pre-milestone deals.
  - `handle_event("add_note", …)` trims the text, stores it as `Note: <text>` via `Alur.Activities.log/2`, refreshes the list, and resets the form. A blank note changes nothing; a note over 500 characters flashes an error. There is no edit or delete affordance anywhere on the log — no route, no event, no context function exposes one.

### Tests (86 total, all green via `mix test`; was 67)

- `test/alur/activities_test.exs` (10, `async: false`) — creating a deal yields exactly its opening `Deal created` line owned by that deal; another deal's lines never leak into this deal's log; `list_for_deal/1` is newest-first across several lines; `log/2` writes one timestamped line and rejects blank and > 500-char descriptions; deleting a deal removes its lines; deleting the contact removes the deals and therefore their lines (two-level DB cascade); `format_when/1` renders WIB times incl. Jakarta midnight date rollover.
- `test/alur/deals_test.exs` (+6 in a new `activity log lines are written for deal events` describe, `async: false`) — create writes the `Deal created` line; `move_deal` writes `Moved from Lead to Meeting` naming both columns; several moves append one line each, newest first; moving to the column the deal is already on writes nothing; refused moves (foreign account's deal, unknown deal, unknown column) never write a line; `update_deal` writes a move line when the column changes but not for other-field edits or re-submitting the same column.
- `test/alur_web/features/activity_log_test.exs` (3, PhoenixTest, `async: false`):
  1. The full UI lifecycle: create a deal from a contact → the deal page opens with one timestamped `Deal created` row; log rows expose no edit/delete affordances; typing a note and clicking **Add note** puts `Note: …` above the created line with a flash; changing the column on the deal-edit page then adds `Moved from Lead to Meeting` on top — three timestamped rows in newest-first order.
  2. A board drag (the exact `move_deal` event the drag hook pushes, via `render_hook`) followed by opening the card shows `Moved from Lead to Meeting` above `Deal created` on the deal's log.
  3. Account isolation: directly opening another account's deal (and so its log) bounces with "Deal not found.", and a second account's own deal page shows only its own lines — never the other account's private note.
- All 67 pre-existing tests pass unchanged.

## Decisions and deviations (not in the PRD)

1. **The PRD's `when` field is modeled as `inserted_at`** (with `:utc_datetime_usec` timestamps). The Ecto-managed insert timestamp *is* the moment the line was written, so no extra `when` column is needed — and microsecond precision keeps newest-first ordering deterministic when several lines are written in the same second.
2. **Timestamps display in WIB without adding a time-zone database.** Jakarta has observed a fixed UTC+7 offset for decades, so `format_when/1` shifts the UTC stamp by plain `DateTime.add/3` arithmetic and renders it with a `WIB` label. No new dependency was needed for milestone 5; milestone 6's Asia/Jakarta *comparison* for overdue due dates may still want a real time-zone database, which can be added then without touching this display.
3. **No `kind`/`type` column — the description carries everything.** PRD activity descriptions ("created, moved, follow-up logged, or a manual note") are all short lines, so each is stored as its own description string (`Deal created`, `Moved from Lead to Meeting`, `Note: <free text>`, later `Follow-up added: …`). Milestone 6's hook point is simply `Alur.Activities.log/2` plus the description it writes; no schema change is required for follow-up lines.
4. **Manual notes are prefixed `Note: ` when stored** so free text reads consistently beside system lines (the log has no kind column to style them differently).
5. **Move logging is detected in `update_deal/2`** — the single choke point every column change already funnels through (deal edit page directly, `move_deal/3` for board drags and later the milestone-8 `PATCH /api/deals/:id`). Only genuine column changes log; same-column saves and same-column drops are silent.
6. **The "created" line and the deal are written atomically** (one `Repo.transaction`), honoring "a deal never exists without its created line"; the returned shapes stay identical to before so no caller changed.
7. **Note form is small by design**: a single text input + ghost button (the page's one signal-green CTA stays "Edit deal"), 500-char cap, blank notes are a no-op.
8. **Log lines are immutable through the whole stack**: no context function, LiveView event, route, or UI exposes editing or deleting a line, matching "not edited or deleted after it is written".
9. Existing pre-milestone deals (created before this migration) have no `Deal created` line and simply show the empty log state until something happens to them; every deal created from now on opens with one.

## Notes for the next milestone

- Milestone 6 (next actions) writes follow-up lines through `Alur.Activities.log/2` (e.g. `Follow-up added: <what>` on add and `Follow-up completed: <what>` on mark-done). No activities schema change is needed; if the To-do page ever needs to *link back* to the log entry that caused a line, a future `kind`/`activity`-id column could be added then — not needed for the PRD.
- `Deals.create_deal/3`, `Deals.update_deal/2`, and `Deals.move_deal/3` are now the account-scoped seams that keep the log honest: milestone 8's `PATCH /api/deals/:id` must keep calling `move_deal/3` (per `docs/decisions.md`) and will get move lines for free.
- The activity timestamp display (WIB, `format_when/1`) and the `Asia/Jakarta` comparisons milestone 6 needs for overdue due dates should share one time-zone story — currently the former is fixed +07:00 arithmetic; decide in milestone 6 whether to introduce a `tz`-style database for comparisons.
- If activity logging ever needs the *old/new column ids* (not just names) or the *actor*, that data is not stored today — the description holds the names and the timestamp holds the moment, which is all the PRD asks for.

## Gate used

`mix precommit` (compile `--warnings-as-errors`, `deps.unlock --unused`, `mix format --check-formatted`, `mix test`, `mix credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`) — **exit 0, 86 tests / 0 failures**, no credo issues, no dialyzer findings, no clones, architecture OK.

Live HTTP checks against `mix phx.server` (port 4031): logged-out `GET /deals/:id` returns `302 → /accounts/log-in`; after logging in through the real form, the deal page HTML contains the `Activity log` panel (`id="deal-activity-log"`) with exactly its rows — after a context-written note and a move, the page renders newest-first `Moved from Lead to Won` (20:05 WIB), `Note: Called Sari about the proposal.` (20:05 WIB), `Deal created` (20:04 WIB), each in a timestamped `<time>` element, plus the note form. The check account and its data were removed afterwards (DB cascade verified: 0 leftover rows).

No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
