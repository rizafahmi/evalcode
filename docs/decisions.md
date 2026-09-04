# Locked implementation decisions

Product scope lives in `prd.html`. This file removes forks so autonomous workers never stall.

## App identity

- OTP app name: `alur`
- Elixir module prefix: `Alur`
- Stack: Phoenix + LiveView + SQLite for CRM UI through milestone 6. From milestone 8, the **Pipeline** board is Vue over REST; contacts, deal pages, activity, and to-dos stay LiveView.
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

## Vue frontend

- Vue 3 + TypeScript + Vite + Vitest live **inside** Phoenix `assets/` (not a sibling `frontend/` app).
- Phoenix serves the built SPA. One OTP app, one server.
- Milestone 7 introduces Vite for the Vue entry; Mix Tailwind can stay. Do not add a second OTP app.
- Milestone 8 replaces the LiveView Pipeline board with Vue on the **same nav/home route**. Drag-to-column must persist and keep activity-log move behavior from milestone 5.

## Domain defaults

- Pipeline columns (seeded, not user-editable), in order: Lead, Meeting, Proposal, Won, Lost.
- Deal amounts are Indonesian Rupiah. Display as `Rp` with Indonesian grouping (e.g. `Rp 15.000.000`).
- Overdue next actions: compare due datetime to **Asia/Jakarta**.
- Every contact, deal, activity, and next action belongs to the signed-in account. Accounts do not share data.

## Quality bar

- ExUnit (+ LiveView tests where the UI is LiveView) must cover each milestone’s “Done when”.
- From milestone 7: ConnCase covers `GET /api/health`; Vitest covers Vue. Run Vitest in the same “done” gate as formatter/credo.
- Run the project formatter and `mix credo` (or the project’s configured linter) before calling a milestone done.
- Local Conventional Commit after each green milestone: `feat(alur): …`. Do not push.

## Ambiguity rule

If something is still ambiguous after the PRD and this file, pick the simplest option that satisfies the PRD, record it in `milestone-log.md`, and continue. Do not ask the user.
