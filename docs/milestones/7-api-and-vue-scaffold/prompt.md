# Milestone 7 — API health and Vue scaffold

You are a worker agent building milestone 7 of Alur. The parent orchestrator is not a human. Stay in agent mode. Do not call `SwitchMode`. Do not use `AskQuestion`. Do not wait for confirmation. Build immediately.

## Context

- Read `docs/prd.html` for full project context, scope, data model, and tech stack.
- Read `docs/decisions.md` for locked implementation defaults.
- Read previous milestone folders (`docs/milestones/*/milestone-log.md`) to understand what has already been built.

## Locked for this milestone

- `GET /api/health` unauthenticated → `200` `{"status":"ok"}`.
- Vue 3 + TypeScript + Vite + Vitest inside `assets/`. Add a Vite watcher (or import the Vue entry from `app.js`) so Phoenix actually serves the bundle in `mix phx.server`.
- Authenticated **`GET /app`**: controller HTML, not LiveView. Empty mount node; Vue boots (`data-v-app`). Stub may show health `ok`.
- Do **not** change `PipelineLive`, mount Vue inside it, or add a nav item. Pipeline stays `/`.
- Do **not** add `/api/deals` yet.

## Your task

1. Implement **only** milestone 7 as defined in the PRD (“API health and Vue scaffold”). Do not build later milestones.
2. On ambiguity, use `docs/decisions.md`; if still unclear, pick the simplest PRD-satisfying option, record it in the log, and continue.
3. Verify against the “Done when” criteria for milestone 7 in the PRD. `mix test` and Vitest are required. Browser-check signed-in `/app` until Vue has mounted.
4. Run the project formatter and linter before calling this done.
5. When complete, write `docs/milestones/7-api-and-vue-scaffold/milestone-log.md` with:
   - **`status: passed` or `status: failed`** near the top (YAML-ish or a clear heading).
   - **`## What's new in the app`** first (human-readable user-facing bullets).
   - Then: what was built (files, models, routes); decisions not in the PRD; notes for the next milestone; deviations and why.
6. On verification failure: fix once. If still red, write the log with `status: failed` and stop. Do not start later milestones.

Never ask the user. Never pause for plan approval.
