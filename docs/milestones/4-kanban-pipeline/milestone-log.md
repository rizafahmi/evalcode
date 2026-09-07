# Milestone 4 Log — Kanban Pipeline

status: passed

## What's new in the app

- **Interactive Kanban Pipeline Board**: The home page (`/`) is now a functional Kanban board organizing sales opportunities across the five standard sales stages: `Lead`, `Meeting`, `Proposal`, `Won`, and `Lost`.
- **Drag-and-Drop Stage Transitions**: Seamlessly drag any deal card from one column and drop it into another to update its stage in real-time. Changes are immediately persisted to the database.
- **Rich Deal Cards**: Each card displays the deal's title, the associated contact's name with an icon, and the opportunity value formatted in Indonesian Rupiah (`Rp 15.000.000`).
- **Direct Card Navigation**: Clicking anywhere on a deal card opens the deal detail page (`/deals/:id`) for deep inspection, editing, or deleting.
- **Dynamic Column Totals**: Every column header displays the exact count of active deals and the aggregated Indonesian Rupiah total (e.g. `Rp 45.000.000`), updating instantly as deals are moved between stages.
- **Smooth Drag UX**: Card dragging features subtle lift feedback (`opacity-40` and `scale-[0.98]`), visual column drop targets (`ring-1 ring-signal-green/40`), and click isolation so dropping cards never triggers accidental page navigation.
- **Multi-tenant Isolation**: Board data and stage transitions are strictly scoped to your authenticated account. No other user can view or alter your pipeline deals.
- **Depot Design Aesthetic**: Handcrafted in Depot dark server-rack styling using a near-black Carbon canvas (`#04040b`), Graphite column containers (`#121113`), Obsidian cards (`#1a191b`), Basalt hairline borders (`#2b292d`), and Signal Green value highlights and CTA buttons.

## What was built

### Contexts & Backend
- `Alur.Deals.get_pipeline_board/1` (`lib/alur/deals.ex`): Groups deals by `pipeline_column_id` for the authenticated `Scope`, calculating individual column deal counts and aggregate IDR sums in a single performant step.
- `Alur.Deals.move_deal/3` (`lib/alur/deals.ex`): Context function that moves a deal to a new stage, accepting `%Deal{}` or binary deal IDs, and `%PipelineColumn{}`, column ID, or column name strings (`"Lead"`, `"Meeting"`, `"Proposal"`, `"Won"`, `"Lost"`). Verifies tenant ownership and column validity.
- `Alur.Deals.change_deal_stage/3` (`lib/alur/deals.ex`): Delegates to `move_deal/3` to ensure consistency for future milestone hooks (such as Milestone 5 activity logging).

### LiveView & Client-Side Hooks
- `AlurWeb.PipelineLive` (`lib/alur_web/live/pipeline_live.ex`): Upgraded from a placeholder shell into the full interactive Kanban board LiveView. Handles `move_deal` events, recalculates column metrics, renders columns in canonical stage order (`Lead`, `Meeting`, `Proposal`, `Won`, `Lost`), and provides empty-column drop zones.
- `KanbanBoard` Hook (`assets/js/kanban.js`): Client-side JavaScript hook using event delegation on the board container for HTML5 drag-and-drop (`dragstart`, `dragover`, `dragenter`, `dragleave`, `drop`, `dragend`). Prevents accidental click navigation on drop via captured click listener and tracks dragging state.
- `assets/js/app.js`: Registered `KanbanBoard` in `LiveSocket` hooks.

### Routes
Placed inside `live_session :require_authenticated_user` with `pipe_through [:browser, :require_authenticated_user]` in `lib/alur_web/router.ex`:
- `live "/", PipelineLive, :index` (existing route updated with full Kanban functionality).

### Tests & Verification
- `test/alur/deals_test.exs`: Context unit tests for `get_pipeline_board/1` and `move_deal/3`, verifying correct column ordering, totals calculation, deal grouping, column name/id flexibility, and cross-account isolation.
- `test/alur_web/live/pipeline_live_test.exs`: LiveView tests for unauthenticated redirect, column rendering, empty board state, deal card display with IDR format, `move_deal` event handling, database persistence, and error handling.
- `test/alur_web/features/pipeline_test.exs`: End-to-end `PhoenixTest` feature suite verifying:
  - Initial load with deals rendered in their respective columns (`Lead`, `Meeting`, `Proposal`) with formatted values and column totals.
  - Dragging a deal from `Lead` to `Meeting` via `render_hook/3` inside `unwrap/2`.
  - Verification that the deal moved to `Meeting` and column totals recalculated (`Lead` -> `Rp 0`, `Meeting` -> `Rp 65.000.000`).
  - Page refresh (`visit(~p"/")`) confirming persistence in the database across sessions.
  - Clicking the deal card navigates directly to `~p"/deals/:id"`.
  - Multi-tenant isolation: another authenticated user sees an empty board with zero totals.
- Verification gate passed: `mix precommit` (`compile --warnings-as-errors`, `deps.unlock --unused`, `format --check-formatted`, `test`, `credo --strict`, `dialyzer`, `ex_dna --max-clones 0`, `reach.check --arch --smells`).

## Decisions not in the PRD

- **Event Delegation for Drag-and-Drop**: Instead of attaching listeners to individual cards that get remounted on DOM morphing, the `KanbanBoard` hook attaches drag and drop event listeners to `this.el` (the board container), ensuring consistent performance without memory leaks or dropped listeners.
- **Click Suppression During Drag**: Used a capturing click event handler in `KanbanBoard` that halts click propagation if a drag operation was completed, preventing browsers from triggering navigation to the deal show page upon dropping a card.
- **Flexible Column Identifier Resolution**: Implemented `Deals.move_deal/3` to resolve pipeline columns either by binary UUID or by canonical column name (`"Lead"`, `"Meeting"`, etc.), allowing both UI drop events and programmatic callers to use the context seamlessly.
- **Empty Column Drop Zone Placeholder**: Provided a dashed placeholder area (`Drop deals here`) with minimum height so empty columns remain valid and easily targetable drop surfaces for dragged cards.

## Notes for the next milestone (Milestone 5 — Activity log)

- Milestone 5 will add activity logging to each deal:
  - A timestamped activity history displayed newest-first on the deal page.
  - Automatic creation of activity log entries when a deal is created and when it moves column (including Kanban drags!).
  - Because `move_deal/3` is now the single centralized entry point for stage moves in `Alur.Deals` (used by both `PipelineLive` and `DealLive.Show`), Milestone 5 can hook into `move_deal/3` to record column change log lines.
  - Ability to add free-text notes to the deal's activity log.
  - Hook points prepared for next-action add/complete events in Milestone 6.

## Deviations and why

None. Implemented strictly Milestone 4 as defined in the PRD.
