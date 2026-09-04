# Locked implementation decisions

Product scope lives in `prd.html`. This file removes forks so autonomous workers never stall.

## App identity

- OTP app name: `alur`
- Elixir module prefix: `Alur`
- Stack: Phoenix + LiveView + SQLite
- Generate **into this repo root** (do not create a nested project). Keep existing `flake.nix`, `_build_plan/`, `AGENTS.md`, `.credo.exs`, `.editorconfig`, `.reach.exs`, `docs/`.

## Auth

- Use `phx.gen.auth` with email/password and LiveView sessions.
- No outbound mailer. No password-reset email in v1.
- Logged-out visitors only see register / sign-in.

## Domain defaults

- Pipeline columns (seeded, not user-editable), in order: Lead, Meeting, Proposal, Won, Lost.
- Deal amounts are Indonesian Rupiah. Display as `Rp` with Indonesian grouping (e.g. `Rp 15.000.000`).
- Overdue next actions: compare due datetime to **Asia/Jakarta**.
- Every contact, deal, activity, and next action belongs to the signed-in account. Accounts do not share data.

## Quality bar

- ExUnit (+ LiveView tests where the UI is LiveView) must cover each milestone’s “Done when”.
- Run the project formatter and `mix credo` (or the project’s configured linter) before calling a milestone done.
- Local Conventional Commit after each green milestone: `feat(alur): …`. Do not push.

## Ambiguity rule

If something is still ambiguous after the PRD and this file, pick the simplest option that satisfies the PRD, record it in `milestone-log.md`, and continue. Do not ask the user.
