# Autonomous run — parent orchestrator

Run milestones 1 → 6 in one session with no human check-ins.

## Sequence

1. `1-login-and-shell`
2. `2-contacts`
3. `3-deals`
4. `4-kanban-pipeline`
5. `5-activity-log`
6. `6-next-actions`

For each N:

1. Launch a Task subagent (`run_in_background: false`) whose prompt is that folder’s `prompt.md` plus: you are a worker; the parent is not a human; never ask the user.
2. When the subagent returns, read `_build_plan/milestones/N-*/milestone-log.md`.
3. Run `mix test` in the repo (via `nix develop -c …` if needed).
4. If the log is missing, says `status: failed`, or tests are red: **retry once** (same milestone). If still red, stop the chain and report.
5. If green: local Conventional Commit (`feat(alur): …`), then start N+1.

## Rules

- No `SwitchMode`. No `AskQuestion`. No waiting for confirmation.
- Do not parallelize milestones.
- Do not push.
- Parent does not implement the CRM; workers do.
- If a worker asks a question anyway, answer from `decisions.md` / the PRD and resume — do not ping the user.
