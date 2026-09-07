# Locked implementation decisions

Product scope lives in `prd.html`. This file removes forks so autonomous workers never stall.

## App identity

- OTP app name: `alur`
- Elixir module prefix: `Alur`
- Stack: Phoenix + LiveView + SQLite for CRM UI. Pipeline nav/home (`/`) stays **LiveView** through v1. From milestone 7, Vue lives on a dedicated controller page at **`GET /app`**. Milestone 8 fills `/app` with a Vue Kanban over REST. Contacts, deal pages, activity, and to-dos stay LiveView.
- Generate **into this repo root** (do not create a nested project). Keep existing `flake.nix`, `AGENTS.md`, `.credo.exs`, `.editorconfig`, `.reach.exs`, `docs/`.

## Auth

- Use `phx.gen.auth` with email/password and LiveView sessions.
- No outbound mailer. No password-reset email in v1.
- Logged-out visitors only see register / sign-in.
- JSON API auth (milestone 8+): reuse **session cookies** (`fetch` with credentials). No JWT or other tokens in v1.

## REST API

- JSON under the `/api` prefix.
- `GET /api/health` is **unauthenticated**, returns `200` with body `{"status":"ok"}`. No extra fields.
- Same origin as the Phoenix app — **no CORS**.
- Milestone 8 (session cookies; unauthenticated → `401`):
  - `GET /api/deals` — account-scoped list (each deal has `id`, `title`, `pipeline_column_id`).
  - `GET /api/deals/:id` — same isolation (`404` if not the current account).
  - `PATCH /api/deals/:id` — JSON body includes `pipeline_column_id`; must call existing `move_deal` so activity-log move lines still fire.
  - `GET /api/pipeline` is optional (board aggregate with column ids). Use it if the Vue board needs column ids that `/api/deals` does not return.

## Vue frontend

- Vue 3 + TypeScript + Vite + Vitest live **inside** Phoenix `assets/` (not a sibling `frontend/` app).
- Phoenix serves the built SPA. One OTP app, one server.
- Milestone 7 introduces Vite for the Vue entry; Mix Tailwind can stay. Do not add a second OTP app.
- **`GET /app`** is an authenticated **controller** page (`pipe_through` browser + require user), **not** a LiveView and **not** inside `live_session`. Empty mount node. Vue `createApp().mount(...)` on that node (Vue 3 sets `data-v-app`).
- Serve the Vite-built entry from Phoenix (import from `app.js`, or a Vite watcher in `config/dev.exs` plus a layout script). Do **not** put a `<script src>` in a LiveView `render/1` and expect it to run. Do **not** mount Vue inside `PipelineLive`. Do **not** add a fourth nav item.
- Milestone 8 grows `/app` into the Vue Kanban. LiveView Pipeline at `/` stays. Drag-to-column on `/app` persists via `PATCH /api/deals/:id` and keeps activity-log move behavior from milestone 5. Card click goes to the LiveView deal page.

## Domain defaults

- Pipeline columns (seeded, not user-editable), in order: Lead, Meeting, Proposal, Won, Lost.
- Deal amounts are Indonesian Rupiah. Display as `Rp` with Indonesian grouping (e.g. `Rp 15.000.000`).
- Overdue next actions: compare due datetime to **Asia/Jakarta**.
- Every contact, deal, activity, and next action belongs to the signed-in account. Accounts do not share data.

## Quality bar

- ExUnit (+ LiveView tests where the UI is LiveView) must cover each milestone’s “Done when”.
- From milestone 7: ConnCase covers `GET /api/health`; Vitest covers Vue. Run Vitest in the same “done” gate as formatter/credo.
- From milestone 8: ConnCase covers `GET /api/deals`, `GET /api/deals/:id`, `PATCH /api/deals/:id` (401, isolation, move).
- Run the project formatter and `mix credo` (or the project’s configured linter) before calling a milestone done.
- Local Conventional Commit after each green milestone: `feat(alur): …`. Do not push.

## Ambiguity rule

If something is still ambiguous after the PRD and this file, pick the simplest option that satisfies the PRD, record it in `milestone-log.md`, and continue. Do not ask the user.
