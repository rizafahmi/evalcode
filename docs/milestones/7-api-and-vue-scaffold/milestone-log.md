# Milestone 7 Log — API Health and Vue Scaffold

status: passed

## What's new in the app

- **Unauthenticated Health Check Endpoint (`GET /api/health`)**: A fast, public REST API endpoint that returns `200 OK` with JSON `{"status":"ok"}` for monitoring and service health verification without requiring authentication or session cookies.
- **Dedicated Authenticated SPA Destination at `/app`**: A controller-rendered HTML page hosted within the standard Alur application shell. Accessible only to logged-in users (unauthenticated visitors are redirected to `/users/log-in`), rendering an initial empty mount node (`<div id="app"></div>`).
- **Vue 3 + TypeScript Client Application**: The Vue frontend toolchain mounts onto `#app` upon page load, setting Vue 3's `data-v-app` attribute. The scaffold stub displays the application title, mount location, and queries `/api/health` to render a live green status badge.
- **Modern Vite & Vitest Toolchain in `assets/`**: Vue 3, TypeScript, Vite, and Vitest are installed directly inside Phoenix `assets/`. Vite compiles the Vue entry into `priv/static/assets/js/vue.js`, while Vitest runs fast unit and component tests via `happy-dom`.
- **Integrated Dev Server Watcher**: Added Vite watch mode to Phoenix Endpoint watchers in `config/dev.exs`, ensuring changes to `.vue` or `.ts` files immediately recompile and trigger live reload in `mix phx.server`.
- **Zero LiveView Regression & Nav Discipline**: The Pipeline board at `/` remains intact as LiveView, Contacts and To-dos are untouched, and no extra navigation item was added to the main header navigation.

## What was built

### Controllers & Templates
- `AlurWeb.HealthController` (`lib/alur_web/controllers/health_controller.ex`): Action `index/2` returning `json(conn, %{status: "ok"})`.
- `AlurWeb.AppController` (`lib/alur_web/controllers/app_controller.ex`): Action `index/2` rendering `:index` template for authenticated users.
- `AlurWeb.AppHTML` (`lib/alur_web/controllers/app_html.ex`): View module embedding templates in `app_html/*`.
- `lib/alur_web/controllers/app_html/index.html.heex`: Renders `<Layouts.app>` shell with empty mount container `<div id="app"></div>`.
- `lib/alur_web/components/layouts/root.html.heex`: Added `<script defer phx-track-static type="text/javascript" src={~p"/assets/js/vue.js"}></script>` to deliver the compiled Vue bundle to browser pages.

### Vue 3 & TypeScript Frontend Toolchain
- `assets/package.json`: Configured with dependencies `vue` (^3.5) and devDependencies `vite`, `@vitejs/plugin-vue`, `vitest`, `@vue/test-utils`, `happy-dom`, `typescript`, `@types/node`.
- `assets/vite.config.mts`: Configures Vite to build `assets/vue/main.ts` as an IIFE library outputting to `../priv/static/assets/js/vue.js` without clearing existing assets, and sets Vitest to use the `happy-dom` environment.
- `assets/vue/main.ts`: Application entry point exporting `mountApp()`, which locates `#app`, verifies no existing mount, initializes `createApp(App)`, and mounts it. Automatically executes on `DOMContentLoaded` or immediately if already loaded.
- `assets/vue/App.vue`: Scaffold component styled with Depot design system tokens (Graphite surface, Basalt hairline borders, Obsidian callout, Signal Green badge), querying `GET /api/health` on mount.
- `assets/vue/env.d.ts`: TypeScript declarations for `.vue` Single File Components.
- `assets/css/app.css`: Added `@source "../vue";` so Tailwind v4 scans Vue components for class generation.

### Router
- In `lib/alur_web/router.ex`:
  - `scope "/api", AlurWeb` with `pipe_through :api`: Placed `get "/health", HealthController, :index` for unauthenticated JSON requests.
  - `scope "/", AlurWeb` with `pipe_through [:browser, :require_authenticated_user]`: Placed `get "/app", AppController, :index` outside of `live_session` as a standard controller route requiring login.

### Phoenix Asset Pipeline & Server Watcher
- `config/dev.exs`: Added `node: ["node_modules/vite/bin/vite.js", "build", "--watch", cd: Path.expand("../assets", __DIR__)]` to `watchers`.
- `mix.exs`: Updated `assets.setup` to run `cmd --cd assets npm install`, `assets.build` and `assets.deploy` to run `cmd --cd assets npm run build`, and `precommit` alias to run `cmd --cd assets npm run test`.

### Tests & Verification
- `test/alur_web/controllers/health_controller_test.exs`: ConnCase tests verifying unauthenticated `GET /api/health` returns status `200` with `{"status" => "ok"}`.
- `test/alur_web/controllers/app_controller_test.exs`: ConnCase tests verifying unauthenticated access to `/app` redirects to `/users/log-in`, and authenticated access returns `200` with `<div id="app"></div>`.
- `test/alur_web/features/api_and_vue_scaffold_test.exs`: End-to-end `PhoenixTest` feature suite verifying the complete milestone flow (unauthenticated health check, login protection, empty mount node in standard shell, lack of unwanted nav items, and static bundle delivery at `/assets/js/vue.js`).
- `assets/vue/__tests__/App.spec.ts`: Vitest unit tests verifying `App.vue` renders title, mount location, default health ok, and handles `/api/health` fetch responses.
- `assets/vue/__tests__/main.spec.ts`: Vitest unit tests verifying `mountApp()` attaches to `#app`, sets `data-v-app`, prevents duplicate mounts, and handles missing target nodes.
- End-to-end headless browser verification (`scratch/verify_vue_mount.mjs`) confirming login against a running Phoenix server, receiving HTML with `<div id="app"></div>`, fetching `/assets/js/vue.js`, executing script, and verifying `data-v-app` is set and scaffold UI is rendered.
- Full verification gate passed via `mix precommit`: 198 ExUnit tests passed, 6 Vitest tests passed, Credo strict 0 issues, Dialyzer 0 errors, ExDNA 0 clones, Reach architecture check clean.

## Decisions not in the PRD

- **IIFE Output Format for Vue Bundle**: Vite is configured with `formats: ['iife']` to output a standalone browser-executable script bundle (`priv/static/assets/js/vue.js`) that includes Vue runtime dependencies and requires no ES module polyfills.
- **Dual Pipeline Integration (Mix Aliases + Dev Watcher)**: The Vue build step was integrated into `mix assets.build` and `mix assets.deploy` via `mix cmd --cd assets npm run build`, and Vitest was added to `mix precommit`, ensuring consistency across development, CI, and production deployments.
- **Tailwind v4 Vue Path Inclusion**: Added `@source "../vue";` to `assets/css/app.css` so Depot tokens and utilities used in Vue SFCs are compiled by Phoenix Tailwind into `app.css`.

## Notes for the next milestone (Milestone 8 — Vue Kanban over REST)

- Implement REST API endpoints:
  - `GET /api/deals`: account-scoped list with `id`, `title`, and `pipeline_column_id`.
  - `GET /api/deals/:id`: account-scoped single deal lookup (`404` if not found or cross-account).
  - `PATCH /api/deals/:id`: JSON body updating `pipeline_column_id`, calling existing `Alur.Deals.move_deal/3` to preserve activity log lines from Milestone 5.
  - Optional `GET /api/pipeline` for board aggregate if needed.
- Enforce session cookie authentication on `/api/deals*` endpoints (unauthenticated requests return `401 Unauthorized`).
- Build Vue Kanban board in `assets/vue/` replacing the scaffold in `App.vue` with 5 columns (Lead, Meeting, Proposal, Won, Lost), column totals, IDR currency formatting, and card click-through to `/deals/:id`.
- Ensure drag-and-drop persistence issues `PATCH /api/deals/:id` requests.

## Deviations and why

None. Implemented strictly Milestone 7 as specified in the PRD and locked decisions.
