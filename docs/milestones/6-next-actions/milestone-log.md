# Milestone 6 Log — Next Actions

status: passed

## What's new in the app

- **Follow-up Action Scheduling on Deals**: On any deal page (`/deals/:id`), you can now schedule follow-ups with a description (`what`), a required due date, and an optional specific due time (`HH:MM`).
- **Clear Separation of Incomplete and Completed Follow-ups**: Incomplete follow-up items are displayed prominently with clear action descriptions, formatted due dates, and one-click "Mark done" buttons. Completed items remain permanently visible in a dedicated completed section with completion timestamps for full auditability.
- **Dedicated Centralized To-dos Dashboard**: The To-dos page (accessible at `/todos` and `/to-dos`) aggregates all open follow-ups across all your deals in one centralized view, ordered soonest due first.
- **Deal Link Click-Through**: Each to-do row shows what needs to be done, when it is due, and the associated deal's title with a direct link navigating straight to that deal.
- **Visually Distinct Overdue Indicators**: If a follow-up's due date and time is in the past according to Indonesian Western Time (Asia/Jakarta / WIB), it is immediately flagged with a prominent "Overdue" badge and rose warning accents on both the To-do page and the deal page.
- **Mark Done from Either View**: You can mark any follow-up as completed directly from the central To-dos dashboard or from the individual deal page.
- **Automatic Deal Activity Stream Recording**: Adding or completing a follow-up automatically writes an immutable event line to the deal's activity log (`"Added next action: [description]"` and `"Completed next action: [description]"`), complete with timestamps and dedicated iconography.
- **Strict Multi-tenant Isolation**: To-dos and follow-up actions belong strictly to the authenticated account; users cannot view, schedule, or complete actions belonging to other users' deals.
- **Depot Design System Compliance**: Styled following the Depot dark developer-console aesthetic with Graphite surfaces, Obsidian header strips, Basalt hairline dividers, and positive letter spacing.

## What was built

### Models and Schemas
- `Alur.NextActions.NextAction` (`lib/alur/next_actions/next_action.ex`): Schema for follow-ups with binary ID primary key, `what` (string, required), `due_date` (date, required), `due_time` (time, optional), `due_at` (utc_datetime, computed from Asia/Jakarta offset), `done` (boolean, default false), `completed_at` (utc_datetime_usec), and associations to `User` and `Deal`.
- `Alur.Deals.Deal` (`lib/alur/deals/deal.ex`): Added `has_many :next_actions, Alur.NextActions.NextAction` association.
- Migration `priv/repo/migrations/20260907030000_create_next_actions.exs`: Creates `next_actions` table with foreign key cascades and composite indexes on `[:user_id, :done, :due_at]` and `[:deal_id, :done]`.

### Contexts & Formatting
- `Alur.NextActions` (`lib/alur/next_actions.ex`): Context module enforcing user scope isolation across all follow-up operations:
  - `list_next_actions_for_deal/2`: Lists all actions for a deal.
  - `list_incomplete_actions_for_deal/2`: Lists incomplete actions for a deal, sorted soonest due first.
  - `list_completed_actions_for_deal/2`: Lists completed actions for a deal, sorted newest completed first.
  - `list_incomplete_actions/1`: Lists all incomplete actions across deals for the signed-in user, sorted soonest due first (`[asc: :due_at, asc: :inserted_at]`), preloading associated deals and contacts.
  - `get_next_action!/2`: Scoped lookup raising `Ecto.NoResultsError` if missing or belonging to another account.
  - `create_next_action/3`: Transactional creation that validates deal ownership and automatically records `"Added next action: #{what}"` via `Activities.log_next_action_added/3`.
  - `complete_next_action/2`: Idempotent transactional completion setting `done: true` and `completed_at`, and automatically recording `"Completed next action: #{what}"` via `Activities.log_next_action_completed/3`.
  - `overdue?/2`: Evaluates whether an incomplete action's due date/time is in the past relative to Asia/Jakarta (UTC+7).
  - `format_due/1`: Formats due date and optional time into human-readable Indonesian date format (e.g. `"10 Sep 2026, 14:00"` or `"10 Sep 2026"`).
- `AlurWeb.CoreComponents` (`lib/alur_web/components/core_components.ex`): Added delegations for `format_due/1` and `overdue?/1`.

### LiveViews & Templates
- `AlurWeb.DealLive.Show` (`lib/alur_web/live/deal_live/show.ex`):
  - Added Next Actions card section with follow-up scheduling form (description, due date, optional time).
  - Renders incomplete follow-ups with overdue badges and mark done buttons.
  - Renders completed follow-ups in a retained list with strikethrough styling and completed timestamps.
  - Added dedicated activity stream badges and icons for `"next_action_added"` and `"next_action_completed"` events.
- `AlurWeb.TodoLive` (`lib/alur_web/live/todo_live.ex`):
  - Loads open actions across all deals, ordered soonest due first.
  - Displays what, when (`format_due`), and deal title with navigate link to `/deals/:deal_id`.
  - Highlights overdue items with distinct rose warning styling.
  - One-click completion from the to-dos table removing items from the open list.
  - Clean empty state when all actions are caught up.

### Routes
Uses authenticated routes in `lib/alur_web/router.ex`:
- `live "/todos", TodoLive, :index`
- `live "/to-dos", TodoLive, :index`
- `live "/deals/:id", DealLive.Show, :show`

### Tests & Verification
- `test/alur/next_actions_test.exs`: Context unit tests for creating actions (date only and date+time), completing actions, activity log integration, soonest-due sorting, overdue detection, Indonesian date formatting, and multi-tenant isolation.
- `test/alur_web/live/deal_live/show_test.exs`: LiveView tests for scheduling follow-ups on deal page, completing follow-ups on deal page, verifying completed items remain visible, and checking overdue callout.
- `test/alur_web/live/todo_live_test.exs`: LiveView tests for `/todos` and `/to-dos` redirecting when logged out, displaying empty state, rendering open actions with deal links in soonest-due order, overdue callouts, one-click completion, and multi-tenant isolation.
- `test/alur_web/features/next_actions_test.exs`: Comprehensive end-to-end `PhoenixTest` feature suite verifying the complete PRD "Done when" flow:
  - Add follow-up on deal page.
  - See on To-do page with deal name.
  - Overdue items visually called out when due date is in the past.
  - Mark done from deal page.
  - Mark done from To-do page.
  - Matching lines recorded in deal activity log for both added and completed actions.
  - Multi-tenant isolation verified between accounts.
- Full verification gate passed: `mix precommit` (`compile --warnings-as-errors`, `format --check-formatted`, `test`, `credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`: 191 tests passed, 0 errors, 0 warnings).

## Decisions not in the PRD

- **Timezone Normalization to Asia/Jakarta (UTC+7)**: Follow-up actions calculate an absolute UTC `due_at` timestamp based on `Asia/Jakarta` time. When no time is provided, the action expires at the end of the day in Jakarta (`23:59:59` WIB / `16:59:59` UTC). This enables simple, highly efficient database indexing and sorting (`ORDER BY due_at ASC`) that naturally surfaces overdue items first, followed by today's items, tomorrow's items, and beyond.
- **Idempotent Action Completion**: `complete_next_action/2` checks if an action is already marked done and returns `{:ok, action}` without writing duplicate activity entries, preventing activity log spam.
- **Preserved Completed History on Deal**: Completed follow-up actions remain visible in a dedicated "Completed" collapsible section on the deal page with timestamps, ensuring full visibility into past commitments alongside the activity log.

## Notes for the next milestone (Milestone 7 — API health and Vue scaffold)

- Milestone 7 begins the REST API and Vue frontend scaffolding:
  - `GET /api/health` unauthenticated endpoint returning `200` with `{"status":"ok"}`.
  - Vite + Vue 3 + TypeScript + Vitest setup inside `assets/`.
  - Dedicated authenticated controller page at `GET /app` with empty mount node.
  - ConnCase tests covering `GET /api/health` and Vitest tests for the Vue component.

## Deviations and why

None. Implemented strictly Milestone 6 as specified in the PRD.
