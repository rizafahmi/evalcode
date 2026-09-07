# Autonomous run — parent orchestrator

Run milestones 1 → 8 in one session with no human check-ins (CRM LiveView milestones 1–6, then Vue/REST milestones 7–8).

## Sequence

1. `1-login-and-shell`
2. `2-contacts`
3. `3-deals`
4. `4-kanban-pipeline`
5. `5-activity-log`
6. `6-next-actions`
7. `7-health-and-vue-setup`
8. `8-vue-kanban-pipeline`

For each N:

1. Launch a Task subagent (`run_in_background: false`) whose prompt is that folder’s `prompt.md` plus: you are a worker; the parent is not a human; never ask the user.
2. When the subagent returns, read `docs/milestones/N-*/milestone-log.md`.
3. Run `mix test` in the repo (via `nix develop -c …` if needed). From milestone 7 onward, also run Vitest as required by that milestone’s “Done when”.
4. If the log is missing, says `status: failed`, or tests are red: **retry once** (same milestone). If still red, stop the chain and report.
5. If green: local Conventional Commit (`feat(alur): …`), then start N+1.

## Rules

- No `SwitchMode`. No `AskQuestion`. No waiting for confirmation.
- Do not parallelize milestones.
- Do not push.
- Parent does not implement the CRM; workers do.
- If a worker asks a question anyway, answer from `decisions.md` / the PRD and resume — do not ping the user.
