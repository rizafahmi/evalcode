# Milestone 1 — Login and shell

You are a worker agent building milestone 1 of Alur. The parent orchestrator is not a human. Stay in agent mode. Do not call `SwitchMode`. Do not use `AskQuestion`. Do not wait for confirmation. Build immediately.

## Context

- Read `docs/prd.html` for full project context, scope, data model, and tech stack.
- Read `docs/decisions.md` for locked implementation defaults.
- Read previous milestone folders (`docs/milestones/*/milestone-log.md`) to understand what has already been built. Milestone 1 has no prior log.

## Your task

1. Implement **only** milestone 1 as defined in the PRD (“Login and shell”). Do not build later milestones.
2. On ambiguity, use `docs/decisions.md`; if still unclear, pick the simplest PRD-satisfying option, record it in the log, and continue.
3. Verify against the “Done when” criteria for milestone 1 in the PRD. `mix test` is required. Use HTTP/browser checks when the feature is visible.
4. Run the project formatter and linter before calling this done.
5. When complete, write `docs/milestones/1-login-and-shell/milestone-log.md` with:
   - **`status: passed` or `status: failed`** near the top (YAML-ish or a clear heading).
   - **`## What's new in the app`** first (human-readable user-facing bullets).
   - Then: what was built (files, models, routes); decisions not in the PRD; notes for the next milestone; deviations and why.
6. On verification failure: fix once. If still red, write the log with `status: failed` and stop. Do not start later milestones.

Never ask the user. Never pause for plan approval.
