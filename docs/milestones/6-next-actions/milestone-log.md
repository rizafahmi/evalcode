# Milestone 6 — Next actions

status: passed

## What's new in the app

- **You can schedule a follow-up on a deal.** A new "Next actions" panel on the deal page takes a description ("What to do"), a due date, and an optional due time. Add one and it appears on the deal immediately, open first.
- **The deal page shows every follow-up.** Open follow-ups are listed soonest due first with a "Mark done" button and a date-only/time-stamped due ("Send the contract · 30 Sep 2026" or "…, 14:00 WIB" when a time was chosen). Completed ones stay visible below the open ones — struck through with a green check, so you keep the history.
- **The To-dos page is now a real to-do list.** It collects every *open* follow-up across all your deals, soonest due first. Each row shows what to do, when it's due, and which deal it belongs to — the deal name links straight to the deal page.
- **Mark done from either place.** The "Mark done" button on the deal page and on the To-dos page both complete the follow-up: it disappears from To-dos (if it was there) and flips to completed on the deal.
- **Overdue items are called out.** A follow-up whose due moment is in the past (compared to the current time in Asia/Jakarta) wears a red **Overdue** chip on both the deal page and the To-dos page.
- **Follow-up events are written into the deal's activity log.** Adding one logs `Follow-up added: …`, completing one logs `Follow-up completed: …` — both newest-first in the same immutable log from milestone 5.
- **Everything stays private to your account.** Your To-dos list only contains follow-ups on your own deals; another account can never see or reach them.

## What was built

### Files, models, routes

No new route was needed: next actions live on the existing authenticated deal page (`live "/deals/:id" → DealsLive :show`) and fill the existing To-dos placeholder (`live "/todos" → TodosLive :index`) created in milestone 1.

- **Migration** — `priv/repo/migrations/20250101000006_create_next_actions.exs`: creates `next_actions` (`id` binary_id PK, `deal_id` → `deals` with `on_delete: :delete_all`, `what` text not null, `due_date` date not null, `due_time` time nullable, `done` boolean not null default false, `utc_datetime` timestamps) plus an index on `deal_id` and one on `(done, due_date, due_time)` for the open-list ordering. Deleting a deal (or a contact, which cascades to its deals) removes its follow-ups via the DB cascade.
- **Schema** — `lib/alur/next_actions/next_action.ex` (`Alur.NextActions.NextAction`): binary_id keys, `what`, `due_date`, `due_time` (optional), `done` (default false), `belongs_to :deal`. The changeset casts only `what`/`due_date`/`due_time`/`done` (`deal_id` is stamped by the context), requires `what` and `due_date`, and caps `what` at 200 characters.
- **Context** — `lib/alur/next_actions.ex` (`Alur.NextActions`):
  - `list_for_deal/1` — every follow-up on a deal, open first then completed, each group soonest due first (within a day, a timed row sorts before a date-only row).
  - `list_open/1` — the To-dos source: joins through the account's deals, returns only `done == false` rows soonest due first, with each row's deal preloaded so the page can link through. Account isolation falls out of the join (`d.account_id == account.id`).
  - `create_for_deal/2` — inserts the follow-up **and** its `Follow-up added: <what>` activity line in one `Repo.transaction`, so a follow-up never exists without its log line (`{:ok, action}` / `{:error, changeset}`).
  - `complete/1` — marks done and writes `Follow-up completed: <what>` in one transaction. Idempotent at the DB level: it reloads the row first, so completing an already-done follow-up (even via a stale struct) never writes a second line; an already-gone row returns `{:error, :not_found}`.
  - `overdue?/2` — compares the due date/time to the current moment in **Asia/Jakarta**, computed as plain UTC+7 arithmetic (Jakarta has a fixed offset, no DST — same story as `Activities.format_when/1`, so no time-zone database was added). A date-only item is due by the end of its Jakarta day and only becomes overdue the next day; a timed item is overdue once its combined moment is past. Completed items are never overdue. Accepts an explicit `now` for deterministic tests.
  - `format_due/1` — renders a date-only due as `30 Sep 2026` and a timed due as `30 Sep 2026, 14:00 WIB`.
- **Shared component** — `lib/alur_web/components/next_action_components.ex` (`AlurWeb.NextActionComponents.next_action_row/1`): the single row markup used by both the deal page and the To-dos page (open rows carry the "Mark done" button pushing a `complete_next_action` event; completed rows carry a green check; the optional deal link is shown only on To-dos). Keeping one copy avoids duplicating ~30 lines of HEEx in two LiveViews (and keeps the `ex_dna --max-clones 0` gate clean).
- **LiveView** — `lib/alur_web/live/deals_live.ex` `:show`:
  - Loads the deal's follow-ups, an "N open" count, and a fresh add-form on mount. A "Next actions" panel (Depot graphite card, chip shows open count) sits between the Details card and the Activity log: the open/completed rows above, then the add form (description + date + optional time + **Add follow-up**).
  - `handle_event("add_next_action", …)` normalizes blanks (empty date/time → nil, description trimmed), calls `create_for_deal/2`, refreshes both the follow-up list **and** the activity log, resets the form, and flashes. Validation failures re-render the form with inline errors.
  - `handle_event("complete_next_action", …)` completes from the deal page and refreshes both lists again (the completion line appears at the top of the log).
- **LiveView** — `lib/alur_web/live/todos_live.ex`: replaced the milestone-1 placeholder with the real To-dos page. It loads `list_open(current_scope)` on mount, renders the rows (soonest first, overdue chipped, deal name linked) inside `#todo-list`, and handles the same `complete_next_action` event, re-listing and flashing afterwards. The empty state keeps the milestone-1 "Nothing due" copy (`register_and_shell_test` still asserts it).

### Tests (106 total, all green via `mix test`; was 86)

- `test/alur/next_actions_test.exs` (17, `async: false`):
  - `create_for_deal/2` — writes the follow-up plus its `Follow-up added:` line above the deal's created line; optional time stays nil; blank `what`/`due_date` rejected with no row and no extra line; > 200-char `what` rejected; a smuggled `deal_id` is ignored.
  - `list_for_deal/1` — only this deal's rows, open first then completed, soonest due first (timed row before a same-day date-only row); other deals never leak in.
  - `list_open/1` — only the account's incomplete rows across all its deals, soonest first, each preloaded with its deal; completed and foreign rows excluded.
  - `complete/1` — flips `done` and logs `Follow-up completed:`; completing twice writes one line (DB-level idempotency); a completed row leaves the open list but stays on the deal.
  - `overdue?/2` — date-only overdue the day after its due day; not overdue on/after the due day; timed items overdue once the moment passes in Jakarta; compares against the Jakarta day rather than the UTC day (a 17:30Z moment is already the next Jakarta day); completed never overdue.
  - `format_due/1` — `30 Sep 2026` date-only, `30 Sep 2026, 14:00 WIB` with a time.
  - Deleting the deal removes its follow-ups.
- `test/alur_web/features/next_actions_test.exs` (3, PhoenixTest, `async: false`):
  1. Full UI lifecycle: add a follow-up with a date and time on the deal page → it appears there (`1 open`) and its `Follow-up added:` line lands above `Deal created` → the To-dos page lists it with the formatted due and the deal name, the row links through to the deal → marking done from To-dos removes it there → back on the deal it stays visible as completed (`0 open`) with `Follow-up completed:` then `Follow-up added:` then `Deal created` in the log.
  2. Ordering + overdue call-out: an overdue and a future follow-up appear soonest first with the **Overdue** chip only on the overdue row (both on To-dos and on the deal page); completing the overdue one from the deal page removes it from To-dos.
  3. Account isolation: Budi's To-dos list shows only Budi's own follow-up and deal, never Sari's private one.
- All 86 pre-existing tests pass unchanged (the To-dos empty state test and every deal/activity test still pass with the new panel in place).

## Decisions and deviations (not in the PRD)

1. **The PRD's `due` (date, optional time) is modeled as two columns: `due_date` (date, not null) + `due_time` (time, nullable).** The optional-time shape is a first-class part of the product copy ("due date, optional time"), so storing it as a single instant would force a fake sentinel time. Ordering and overdue checks combine the two in SQL/Elixir; a date-only row is treated as due by the end of its Jakarta day (`asc_nulls_last` keeps it after same-day timed rows).
2. **`what` is capped at 200 characters** (like deal titles) so the longest possible `Follow-up added: …` / `Follow-up completed: …` line (216 chars) fits comfortably under the activity line's 500-character cap from milestone 5.
3. **Overdue compares in Asia/Jakarta with plain UTC+7 arithmetic, no time-zone database.** Jakarta's offset has been a fixed UTC+7 for decades (same reasoning milestone 5 used for `format_when/1`), so "now in Asia/Jakarta" is `DateTime.add(utc_now, 7h)` read as wall time. This closes the milestone-5 handoff note ("decide in milestone 6 whether to introduce a tz database") — no new dependency, one shared time-zone story.
4. **Completed follow-ups cannot be reopened.** The PRD only asks to mark done, so there is no "reopen" affordance (context `complete/1` is the only state change). Similarly there is no edit or delete for a follow-up — not in the PRD, and the immutability theme of milestone 5's log applies to the log lines themselves (which is why follow-ups can be completed but their log lines are never editable).
5. **Follow-up lines reuse `Alur.Activities.log/2` unchanged** (the milestone-5 hook point): `Follow-up added: <what>` on add and `Follow-up completed: <what>` on complete, both inside the same transaction as the follow-up write. No activities schema change was needed, exactly as milestone 5 predicted.
6. **The shared row component lives in one file** (`AlurWeb.NextActionComponents.next_action_row/1`) rather than being inlined in both pages — the rows are ~30 lines of identical markup and `ex_dna --max-clones 0` would flag a second copy.
7. **The To-dos list has no pagination/filtering** — a personal CRM's open-follow-up set is small, and the PRD asks only for "all incomplete actions across deals, soonest due first".
8. **Event name `complete_next_action`** (not `complete`) avoids any future collision with milestone-8-era board events on shared LiveView pages.

## Notes for the next milestone

- Milestone 7+ keeps `GET /todos` as a LiveView page (per `docs/decisions.md`, only the pipeline nav/home and `/app` change). Nothing here blocks the Vue/API milestones.
- The JSON API surface of milestone 8 is deal-only; it never touches next actions, so `Alur.NextActions` stays LiveView-internal.
- `Alur.Deals` unchanged in this milestone — `move_deal/3`/`update_deal/2` remain the single choke point for move logging, and milestone 8's `PATCH /api/deals/:id` should keep calling `move_deal/3` as the decisions file requires.
- If a future milestone ever wants "follow-ups due today" or a calendar view, `due_date`/`due_time` are stored in the user's (Jakarta) wall-clock terms, so those queries compare directly against the Jakarta date — no instant math needed.
- The deal page's Next actions panel is one more place a "not found/foreign" guard would matter if routes ever grow; today the panel only ever renders for an account-scoped deal fetched by `get_deal/2`.

## Gate used

`mix precommit` (compile `--warnings-as-errors`, `deps.unlock --unused`, `mix format --check-formatted`, `mix test`, `mix credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`) — **exit 0, 106 tests / 0 failures**, no credo issues, no dialyzer findings, no code clones, architecture OK.

Done-when verification for milestone 6 is covered end-to-end by the three PhoenixTest feature tests (add on a deal → present on To-dos with the deal name → overdue called out → mark done from either page → matching `Follow-up added:`/`Follow-up completed:` activity-log lines), plus the 17 context tests for the same behaviors at the data layer.

No commit was made by this worker (the parent orchestrator commits each green milestone per `docs/run-autonomous.md`).
