# Milestone 8 Log — Vue Kanban over REST

status: passed

## What's new in the app

- **Full Vue Kanban Pipeline at `/app`**: The dedicated controller page at `/app` now hosts a client-side Vue 3 + TypeScript Kanban board mirroring the 5 sales pipeline stages (`Lead`, `Meeting`, `Proposal`, `Won`, `Lost`).
- **REST-Driven Pipeline & Deal Synchronization**: The Vue board dynamically fetches stage columns and deals through authenticated JSON REST API endpoints using existing browser session cookies (`GET /api/pipeline` and `GET /api/deals`).
- **Interactive Drag-and-Drop Column Transitions**: Dragging deal cards between stage columns instantly moves the opportunity and updates column card counts and aggregated Indonesian Rupiah totals (`Rp 15.000.000`).
- **Backend Move Persistence & Audit Logging**: Dropping a deal card onto a new stage column issues an HTTP `PATCH /api/deals/:id` request with `pipeline_column_id`. The backend executes `Alur.Deals.move_deal/3`, updating the database and recording immutable activity log move entries (`"Moved to [Stage]"`).
- **Direct Navigation to LiveView Deal Pages**: Clicking any deal card navigates directly to the comprehensive LiveView deal detail page (`/deals/:id`). Drag operations cleanly isolate click propagation to prevent accidental navigation on drop.
- **Optimistic UI with Automatic Error Recovery**: Stage moves update the user interface immediately for responsive interaction; if a network or server error occurs, the board automatically rolls back the deal to its previous stage and displays an informative alert.
- **Strict Multi-Tenant Isolation**: The REST API endpoints enforce user scope boundaries. Users cannot view, access, or move deals belonging to other accounts, returning `404 Not Found` for cross-tenant lookups.
- **Zero LiveView Regression**: The main pipeline board at `/` remains intact as a LiveView, the header navigation retains its 3 standard tabs (Pipeline, Contacts, To-dos) without a fourth nav item, and unauthenticated API requests return `401 Unauthorized`.

## What was built

### REST API Endpoints & Auth
- `AlurWeb.UserAuth.require_authenticated_api_user/2` (`lib/alur_web/user_auth.ex`): Plug returning `401 Unauthorized` with JSON `{"error": "unauthorized"}` when unauthenticated, instead of redirecting to login.
- `AlurWeb.DealController` (`lib/alur_web/controllers/deal_controller.ex`):
  - `index/2`: Lists user-scoped deals as JSON array.
  - `show/2`: Returns deal details for owner; returns `404` if non-existent or belonging to another account.
  - `update/2`: Accepts `pipeline_column_id`, calls `Alur.Deals.move_deal/3` to persist stage transition and log move activity, returns updated deal or validation error (`422`).
- `AlurWeb.DealJSON` (`lib/alur_web/controllers/deal_json.ex`): Serializes `%Deal{}` structs to JSON maps with `id`, `title`, `amount`, `notes`, `pipeline_column_id`, `contact` (id, name, email, phone), and timestamps.
- `AlurWeb.PipelineController` (`lib/alur_web/controllers/pipeline_controller.ex`):
  - `index/2`: Returns board aggregate (`{"columns": [...]}`) with column order, total IDR amounts, counts, and preloaded deals.
- Router (`lib/alur_web/router.ex`):
  - Defined `:api_authenticated` pipeline (`[:accepts, "json"], :fetch_session, :fetch_current_scope_for_user, :require_authenticated_api_user`).
  - Added `scope "/api", AlurWeb` with `pipe_through [:api_authenticated]` for `/deals`, `/deals/:id`, and `/pipeline`.

### Vue 3 & TypeScript Kanban Components
- `assets/vue/types.ts`: TypeScript interfaces for `Deal`, `Contact`, and `PipelineColumn`.
- `assets/vue/utils.ts`: `formatIdr()` (Indonesian Rupiah formatting), `stageBadgeClass()` (Depot styling), and `DEFAULT_COLUMNS` fallback array.
- `assets/vue/components/DealCard.vue`: Draggable card displaying deal title, contact name with user icon, IDR amount, drag styling (`opacity-40 scale-[0.98]`), click suppression during drag, and navigation link to `/deals/:id`.
- `assets/vue/components/KanbanColumn.vue`: Column container with Depot design tokens (`bg-graphite border border-basalt`), stage badge, deal count, formatted IDR total, HTML5 dragover/dragenter/dragleave/drop handling with active highlight ring, and empty column placeholder.
- `assets/vue/App.vue`: Kanban board container managing reactive state (`columns`, `deals`, `loading`, `errorMessage`), fetching `/api/pipeline` and `/api/deals` on mount, handling card drop with optimistic updates, issuing `PATCH /api/deals/:id`, and error rollback.
- Built bundle compiled via Vite into `priv/static/assets/js/vue.js`.

### Tests & Verification
- `test/alur_web/controllers/deal_controller_test.exs`: ConnCase tests covering `GET /api/deals`, `GET /api/deals/:id`, and `PATCH /api/deals/:id` (401 unauthenticated, account isolation, 404, 422 validations, stage move, activity log move record generation).
- `test/alur_web/controllers/pipeline_controller_test.exs`: ConnCase tests covering `GET /api/pipeline` (401 unauthenticated, 200 board aggregate with column counts and IDR totals).
- `test/alur_web/features/vue_kanban_pipeline_test.exs`: End-to-end feature suite covering:
  - Unauthenticated redirect on `/app`.
  - Authenticated `#app` mount container with standard navigation shell (no fourth nav item).
  - Session cookie authentication across `/api/deals`, `/api/pipeline`, and `/api/deals/:id`.
  - Deal move persistence and activity log generation in database.
  - Automated browser bundle verification script (`test/support/verify_vue_board.mjs`) testing `vue.js` mounting with `data-v-app`, column placement, IDR totals, card links to `/deals/:id`, drag event issuing `PATCH`, and persistence across reloads.
- `assets/vue/__tests__/utils.spec.ts`: Unit tests for IDR currency formatting and stage badge classes.
- `assets/vue/__tests__/DealCard.spec.ts`: Component tests for deal card layout, link href, and fallback states.
- `assets/vue/__tests__/KanbanColumn.spec.ts`: Component tests for column header metrics, card listing, and empty state.
- `assets/vue/__tests__/main.spec.ts`: Unit tests for `mountApp()` target mounting and lifecycle attributes.
- `assets/vue/__tests__/App.spec.ts`: Component tests for 5-column board rendering, API fetching, totals calculation, card click-through, drop event issuing `PATCH /api/deals/:id`, and rollback on failure.
- Full verification gate passed: `mix precommit` (216 ExUnit tests passed, 20 Vitest tests passed, Credo strict 0 issues, Dialyzer 0 errors, ExDNA 0 clones, Reach architecture check clean).

## Decisions not in the PRD

- **Session Cookie Re-use for REST API**: Configured pipeline `:api_authenticated` to utilize `fetch_session` and `fetch_current_scope_for_user` with `require_authenticated_api_user/2`, avoiding token management complexity while adhering to standard same-origin cookie security.
- **Cross-Account 404 Response**: For both `GET /api/deals/:id` and `PATCH /api/deals/:id`, requests targeting records belonging to another account return `404 Not Found` rather than `403 Forbidden` to avoid leaking deal ID existence.
- **Optimistic UI with Rollback**: When a deal card is dragged and dropped, the Vue state updates immediately and recalculates column metrics before the HTTP `PATCH` finishes. If the server rejects the move or network fails, the deal reverts to its previous column and displays an error banner.
- **Automated Browser Bundle Test in ExUnit**: Integrated `test/support/verify_vue_board.mjs` into `vue_kanban_pipeline_test.exs` via `System.cmd/3` to ensure that every `mix test` run verifies the compiled `vue.js` artifact against a DOM environment.

## Notes for the next milestone

- All core CRM capabilities and both Kanban implementations (LiveView at `/` and Vue over REST at `/app`) are complete and verified.
- Ensure any future endpoints under `/api` adhere to the `:api_authenticated` pipeline for consistent session cookie authentication and JSON 401 handling.

## Deviations and why

None. Implemented strictly Milestone 8 as specified in the PRD and locked decisions.
