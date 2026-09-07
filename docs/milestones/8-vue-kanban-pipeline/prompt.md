# Milestone 8 — Vue Kanban over REST

You are a worker agent building milestone 8 of Alur. The parent orchestrator is not a human. Stay in agent mode. Do not call `SwitchMode`. Do not use `AskQuestion`. Do not wait for confirmation. Build immediately.

## Context

- Read `docs/prd.html` for full project context, scope, data model, and tech stack.
- Read `docs/decisions.md` for locked implementation defaults.
- Read previous milestone folders (`docs/milestones/*/milestone-log.md`) to understand what has already been built.

## Locked for this milestone

- Grow **`GET /app`** (the M7 controller page) into the Vue Kanban. Do **not** replace or wrap `PipelineLive`. Pipeline nav stays LiveView at `/`. No fourth nav item.
- REST (session cookies; unauthenticated → 401): `GET /api/deals`, `GET /api/deals/:id`, `PATCH /api/deals/:id` with `pipeline_column_id` via existing `move_deal`. `GET /api/pipeline` optional.
- Browser-check `/app`: Vue mounted (`data-v-app`); deals in the right columns; drag Lead→Meeting issues `PATCH /api/deals/:id`; refresh stays in Meeting; totals match; card click opens LiveView `/deals/:id`.

## Your task

1. Implement **only** milestone 8 as defined in the PRD (“Vue Kanban over REST”). Do not build later milestones or features.
2. On ambiguity, use `docs/decisions.md`; if still unclear, pick the simplest PRD-satisfying option, record it in the log, and continue.
3. Verify against the “Done when” criteria for milestone 8 in the PRD. `mix test` and Vitest are required. Use HTTP/browser checks on `/app` (not Pipeline).
4. Run the project formatter and linter before calling this done.
5. When complete, write `docs/milestones/8-vue-kanban-pipeline/milestone-log.md` with:
   - **`status: passed` or `status: failed`** near the top (YAML-ish or a clear heading).
   - **`## What's new in the app`** first (human-readable user-facing bullets).
   - Then: what was built (files, models, routes); decisions not in the PRD; notes for the next milestone; deviations and why.
6. On verification failure: fix once. If still red, write the log with `status: failed` and stop.

Never ask the user. Never pause for plan approval.
