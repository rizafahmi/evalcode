# Milestone 5 Log — Activity Log

status: passed

## What's new in the app

- **Timestamped Activity Stream**: Each deal detail page (`/deals/:id`) now features a dedicated activity log displaying an immutable chronological history of everything that happened to the deal, ordered newest-first.
- **Automatic Deal Creation Tracking**: Creating a new opportunity automatically logs a `"Deal created"` entry with an exact timestamp.
- **Stage Movement Tracking Across Board and Detail Views**: Whenever a deal moves between pipeline stages—whether dragged on the Kanban board (`/`) or updated via stage pills/select on the deal page (`/deals/:id`)—a move line (`"Moved to [Stage]"`) is automatically recorded with date and time. Moves to the same stage are recognized as no-ops and avoid duplicate log spam.
- **Manual Note Logging**: You can type free-text notes directly on the deal page to capture discussions, customer updates, or meeting summaries. Notes instantly appear at the top of the activity stream.
- **Append-Only Immutability**: All activity lines are strictly permanent and cannot be edited or deleted by any user, ensuring a reliable audit trail.
- **Local Indonesian Time Formatting**: All timestamps are formatted into human-readable Indonesian Western Time (WIB / UTC+7, e.g. `07 Sep 2026, 14:30`) with full date and time details.
- **Strict Multi-tenant Isolation**: Activity logs are strictly private to the authenticated owner of the deal. Another user account cannot view or write activities to your deals.
- **Depot Server-Rack Terminal Styling**: Designed following Depot design specifications with Graphite card panels, Obsidian header surfaces, Basalt hairline dividers, custom activity type badges (green sparkle for creation, violet arrow for moves, silver chat bubble for notes), and positive letter-spacing for dark-mode readability.

## What was built

### Models and Schemas
- `Alur.Activities.Activity` (`lib/alur/activities/activity.ex`): Schema for activities with binary ID primary key, `description` (required, max 5000 chars), `action_type` (`"created"`, `"moved"`, `"note"`, `"next_action_added"`, `"next_action_completed"`), `metadata` (map for transition details), foreign keys to `users` and `deals`, and `timestamps(type: :utc_datetime_usec)`.
- `Alur.Deals.Deal` (`lib/alur/deals/deal.ex`): Added `has_many :activities, Alur.Activities.Activity` association.
- Migration `priv/repo/migrations/20260907020000_create_activities.exs`: Creates `activities` table with indexes on `[:user_id]`, `[:deal_id]`, and `[:deal_id, :inserted_at]`.

### Contexts & Formatting
- `Alur.Activities` (`lib/alur/activities.ex`): Context module enforcing user scope isolation across all activity operations:
  - `list_activities_for_deal/2`: Returns deal activities ordered newest-first (`order_by: [desc: a.inserted_at, desc: a.id]`).
  - `log_activity/3`: Inserts an activity record belonging to the authenticated scope.
  - `log_deal_created/2`: Records `"Deal created"` upon new opportunity creation.
  - `log_deal_moved/4`: Records `"Moved to #{column_name}"` with old and new column metadata.
  - `log_note/3`: Records a free-text manual note.
  - `log_next_action_added/3` & `log_next_action_completed/3`: Pre-built hook points for Milestone 6.
  - `format_activity_time/1`: Formats UTC datetimes into Indonesian Western Time (`%d %b %Y, %H:%M`).
- `Alur.Deals` (`lib/alur/deals.ex`):
  - Updated `create_deal/2` to automatically log `"Deal created"` within the database transaction.
  - Updated `move_deal/3` to compare old and new column IDs and automatically log `"Moved to #{column_name}"` within the database transaction.
- `AlurWeb.CoreComponents` (`lib/alur_web/components/core_components.ex`): Added `format_activity_time/1` delegation.

### LiveView & Templates
- `AlurWeb.DealLive.Show` (`lib/alur_web/live/deal_live/show.ex`):
  - Loads deal activities on mount and refreshes them when stages change or notes are submitted.
  - Added "Add note" form with textarea, validation against blank notes, and secondary button styling.
  - Renders the activity stream in newest-first order with distinct iconography and timestamps.
  - Completely omits edit and delete controls for log lines.

### Routes
Uses existing authenticated routes in `lib/alur_web/router.ex`:
- `live "/deals/:id", DealLive.Show, :show`

### Tests & Verification
- `test/alur/activities_test.exs`: Context unit tests for activity listing, creation logging, move logging with metadata, manual note recording, newest-first sorting, Milestone 6 hook points, timestamp formatting, and multi-tenant isolation.
- `test/alur/deals_test.exs`: Verified deal creation and moves automatically record activity log lines.
- `test/alur_web/live/deal_live/show_test.exs`: LiveView tests for activity log display, stage move log line generation, note submission, blank note validation, and absence of edit/delete controls.
- `test/alur_web/features/activities_test.exs`: Comprehensive end-to-end `PhoenixTest` feature suite verifying:
  - Creating a deal logs a created line.
  - Dragging a deal on the Kanban board adds a move line with timestamp.
  - Changing stage on the deal page adds a move line with timestamp.
  - Submitting a manual note displays the note in the log.
  - Verification that lines are ordered newest-first.
  - Verification that lines cannot be edited or deleted.
  - Multi-tenant isolation between accounts.
- Full verification gate passed: `mix precommit` (`compile --warnings-as-errors`, `format --check-formatted`, `test`, `credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`: 171 tests passed, 0 errors, 0 warnings).

## Decisions not in the PRD

- **Microsecond Precision Timestamps**: Used `:utc_datetime_usec` for activity timestamps to guarantee deterministic newest-first ordering even when multiple activities or notes occur within the same second during rapid user interaction or test execution.
- **Transactional Consistency**: Wrapped deal creation and stage moves in database transactions alongside activity logging so deal records and their corresponding activity lines are always committed atomically.
- **No-Op Move Protection**: When `move_deal/3` is called with the column the deal is already in, it skips logging a move line, preventing duplicate log spam.
- **Hook Points for Milestone 6**: Added `log_next_action_added/3` and `log_next_action_completed/3` to `Alur.Activities` so Milestone 6 can log next action lifecycle events without refactoring the activity system.

## Notes for the next milestone (Milestone 6 — Next actions)

- Milestone 6 will implement Next Actions (to-dos):
  - Follow-up items attached to deals with a description (`what`), due date/optional time (`due`), and completion flag (`done`).
  - Next actions will be visible on the deal page and on the dedicated To-do page (`/todos` and `/to-dos`).
  - Overdue items need to be compared against `Asia/Jakarta` datetime.
  - Adding and completing follow-ups should invoke the hook points `Activities.log_next_action_added/3` and `Activities.log_next_action_completed/3` so matching lines appear in the deal's activity log.

## Deviations and why

None. Implemented strictly Milestone 5 as specified in the PRD.
