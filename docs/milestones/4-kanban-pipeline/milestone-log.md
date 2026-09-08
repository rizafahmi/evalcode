status: passed

## What's new in the app

- Signed-in users now see their deals on a five-column Kanban board: Lead, Meeting, Proposal, Won, and Lost.
- Board cards show the deal title, contact name, and Indonesian Rupiah value.
- Users can drag a card to another column, and the new status persists after refresh.
- Each column shows its card count and IDR total; clicking a card opens the deal page.

## What was built

- Added `Alur.Deals.list_pipeline_deals/1` for account-scoped board data with contact and column preloads.
- Added `Alur.Deals.move_deal/3` for account-safe moves between seeded pipeline columns.
- Replaced the Pipeline placeholder with the board in `lib/alur_web/live/pipeline_live.ex`.
- Added the `PipelineBoard` drag/drop hook in `assets/js/app.js`, which pushes move events to the LiveView.
- Added authenticated LiveView coverage in `test/alur_web/live/pipeline_live_test.exs` for board rendering, totals, links, movement, persistence, and account isolation.

## Decisions not in the PRD

- Drag/drop uses a small client-side LiveView hook with native HTML drag events; the server remains authoritative for the move and re-renders the board.
- Board totals are calculated from the account-scoped deal list in the LiveView rather than adding a separate aggregate query.
- The existing `/` authenticated `:require_authenticated_user` LiveView route remains the Pipeline entry point, so no router changes were needed.

## Notes for the next milestone

- Deal movement currently has no activity-log side effect, intentionally leaving move history for Milestone 5.
- The board uses the existing seeded pipeline columns and does not expose column editing, filtering, swimlanes, WIP limits, or card colors.

## Deviations

- None.

## Verification

- `mix format` passed.
- Focused domain and LiveView tests passed: 8 tests.
- `mix precommit` passed: 125 tests, Credo, Dialyzer, ExDNA, and Reach.
- The Phoenix server compiled and started on `127.0.0.1:4000`; loopback `curl` smoke checking was blocked by the execution sandbox, so visible behavior was verified through LiveView tests instead.
