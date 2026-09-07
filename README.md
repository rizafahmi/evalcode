# evalcode

A worked example of a self-built LLM coding benchmark. Agents implement **Alur**, a Phoenix 1.8 LiveView CRM, against a PRD. Grading uses held-out tests the model never sees.

[![Pages](https://github.com/rizafahmi/evalcode/actions/workflows/pages.yml/badge.svg)](https://github.com/rizafahmi/evalcode/actions/workflows/pages.yml)
[![Elixir](https://img.shields.io/badge/Elixir-1.20-4B275F?logo=elixir&logoColor=white)](https://elixir-lang.org)
[![OTP](https://img.shields.io/badge/OTP-27-A90533?logo=erlang&logoColor=white)](https://www.erlang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FD4F00)](https://www.phoenixframework.org)
[![LiveView](https://img.shields.io/badge/LiveView-1.1-orange)](https://hexdocs.pm/phoenix_live_view)
[![Last commit](https://img.shields.io/github/last-commit/rizafahmi/evalcode)](https://github.com/rizafahmi/evalcode/commits/main)
[![Issues](https://img.shields.io/github/issues/rizafahmi/evalcode)](https://github.com/rizafahmi/evalcode/issues)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

🏆 **Leaderboard:** [rizafahmi.github.io/evalcode](https://rizafahmi.github.io/evalcode/)

---

## Benchmark results

| Rank | Agent / Harness | Model | Branch | PRD | Tokens | Cost | UI Ready | A11y | Tests | Coverage |
| :---: | :--- | :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 🥇 1 | Antigravity CLI | Gemini 3.8 Flash (High) | [`evalcode_agy`](https://github.com/rizafahmi/evalcode/tree/evalcode_agy) | 8/8 (100%) | 86.7M (99.2% cached) | $1.92 (est) | **40.0 ms** | 6 viols | 122 passed (31 files) | 88.5% |
| 🥈 2 | DeepSeek Harness | DeepSeek V4 Flash (High) | [`evalcode_dsh`](https://github.com/rizafahmi/evalcode/tree/evalcode_dsh) | 8/8 (100%) | 86.7M (99.2% cached) | **$1.37** | 44.2 ms | **5 viols** | 122 passed (18 files) | 88.5% |

> Latency measured via Playwright UI probes (`deal-open` drawer median). Accessibility audited via Axe-core (WCAG 2.2 AA). For full milestone curves, latency distributions, and cost formulas, visit the [interactive leaderboard](https://rizafahmi.github.io/evalcode/).

---

## What this repo is

This GitHub repository is the **eval harness and public starter**, not a finished product CRM.

| Piece | Role |
| --- | --- |
| `main` | Phoenix 1.8 + SQLite app (`:alur`) plus the PRD, milestones, and agent instructions |
| `evalcode_*` branches | Isolated agent runs, with `report/` files when a run finishes |
| GitHub Pages | Static leaderboard built from those branches |

Held-out tests used for scoring are **not** in this tree. That is intentional.

---

## The task: Alur

Alur is the app agents are asked to build: a personal CRM for contacts and deals in Indonesian Rupiah.

Planned product (see the PRD):

- Email/password accounts (`phx.gen.auth`). No outbound mail in v1.
- Contacts, deals, a LiveView Kanban at `/`, activity history, and next actions.
- From milestone 7, Vue 3 + TypeScript + Vite inside `assets/`, served at `GET /app`.
- JSON under `/api`. `GET /api/health` is unauthenticated and returns `{"status":"ok"}`.

`main` today is still the Phoenix starter (Depot-styled home at `/`). The CRM exists as spec and worker prompts until a run implements it.

---

## Getting started

Toolchain is pinned by the Nix flake: **Elixir 1.20.x** and **Erlang/OTP 27**. `mix.exs` allows `elixir: "~> 1.15"`; use the flake for the intended versions.

**With Nix** (and [direnv](https://direnv.net/) if you use it — `.envrc` is `use flake`):

```sh
nix develop
mix setup
mix phx.server
```

**Without Nix**, install Elixir 1.20, OTP 27, Node.js 22, and SQLite, then run the same `mix` commands.

Open [http://localhost:4000](http://localhost:4000).

Useful Mix aliases:

| Command | What it does |
| --- | --- |
| `mix setup` | Hex deps, Ecto create/migrate/seed, Tailwind + esbuild |
| `mix test` | Create/migrate test DB, then ExUnit |
| `mix precommit` | Compile warnings-as-errors, format check, tests, Credo, Dialyzer, ExDNA, Reach |
| `mix ecto.reset` | Drop and recreate the SQLite database |

---

## Tests and quality

- ExUnit lives under `test/`. Feature tests use [PhoenixTest](https://github.com/germsvel/phoenix_test); notes in [`docs/phoenix-test.md`](docs/phoenix-test.md).
- PhoenixTest does not drive JavaScript. Vue coverage (from milestone 7) is Vitest in `assets/`.
- UI work follows [`DESIGN.md`](DESIGN.md) (Depot: dark console, hairline borders, Signal Green for the primary CTA only).
- Agent conventions for this app are in [`AGENTS.md`](AGENTS.md).

---

## Repo layout

```
.
├── lib/alur, lib/alur_web   # OTP app (module prefix Alur)
├── assets/                  # Tailwind, esbuild; Vue lives here from M7
├── config/, priv/, test/
├── docs/prd.html            # Product requirements
├── docs/decisions.md        # Locked implementation defaults
├── docs/milestones/         # Required: one prompt.md per milestone
├── docs/run-autonomous.md   # Optional: one-session parent orchestrator
├── flake.nix                # Dev shell (Elixir 1.20 / OTP 27)
└── .github/
    ├── workflows/pages.yml  # Leaderboard deploy
    └── scripts/build_leaderboard.py
```

---

## Milestones

Runs go 1 → 8 in order. Do not skip.

The required protocol is **manual**: for each milestone, give the coding agent that folder’s `prompt.md` only. Finish (or fail) that milestone before starting the next. Optional: a parent agent can chain them in one session using [`docs/run-autonomous.md`](docs/run-autonomous.md).

| # | Folder | Scope |
| --- | --- | --- |
| 1 | `1-login-and-shell` | Auth and app shell |
| 2 | `2-contacts` | Contacts |
| 3 | `3-deals` | Deals |
| 4 | `4-kanban-pipeline` | LiveView pipeline at `/` |
| 5 | `5-activity-log` | Deal activity history |
| 6 | `6-next-actions` | Follow-ups / to-dos |
| 7 | `7-api-and-vue-scaffold` | `GET /api/health` and Vue at `/app` |
| 8 | `8-vue-kanban-pipeline` | Vue Kanban over REST |

Pipeline columns (seeded): Lead, Meeting, Proposal, Won, Lost. Deal amounts display as `Rp` with Indonesian grouping. Overdue next actions use **Asia/Jakarta**.

---

## Leaderboard and eval branches

Push or merge to `main` or `evalcode_*` triggers [`.github/workflows/pages.yml`](.github/workflows/pages.yml). The workflow runs:

```sh
python3 .github/scripts/build_leaderboard.py --output-dir _site
```

The script scans git refs for `report/perf.md`, `report/execution.md`, `report/score.md`, and `report/a11y.md`. Build locally the same way if you want a `_site/` preview.

---

## Docs

- [PRD](docs/prd.html) — product, data model, “done when”
- [Locked decisions](docs/decisions.md)
- [PhoenixTest](docs/phoenix-test.md)
- [Phoenix guides](https://hexdocs.pm/phoenix/overview.html)
- [`docs/run-autonomous.md`](docs/run-autonomous.md) — optional one-session orchestrator; not required for a valid run

The PRD notes that `prd.html`, `decisions.md`, `run-autonomous.md`, and `docs/milestones/` are build-plan artifacts for the initial run. Keep `docs/phoenix-test.md`.

---

## Contributing

Issues and pull requests are welcome.

**Harness / docs / leaderboard code** — change `main` as usual. Conventional Commits. Run `mix precommit` when the Phoenix app is involved. Match Depot tokens in [`DESIGN.md`](DESIGN.md) for UI.

**A benchmark run** — do **not** merge the implemented CRM into `main`. The leaderboard reads isolated `evalcode_*` branches.

### Submit a run

1. Fork this repo. Branch from `main` as `evalcode_<harness>_<model>` (letters, numbers, underscores). Example: `evalcode_cursor_sonnet`.
2. Run milestones **1 → 8** in order on that branch. For each milestone, paste that folder’s `docs/milestones/<n>-*/prompt.md` into the coding agent. Do not start N+1 until N is done. [`docs/run-autonomous.md`](docs/run-autonomous.md) is optional if you want a parent agent to chain them.
3. Add a `report/` directory. The leaderboard looks for:

   | File | Who writes it |
   | --- | --- |
   | `report/execution.md` | You. First heading after any “Getting Started” notes must be `# Harness - Model` (the builder parses that). Per-milestone `## M1` … `## M8` sections with time, cost, and `Result: N passed` are useful. |
   | `report/perf.md`, `report/a11y.md` | Include them if you generated them. Omit rather than invent numbers. |
   | `report/score.md` | Held-out rubric. **You cannot produce an official score from this repo.** Leave it out; a maintainer can grade the branch after merge-to-branch. |

4. Open a pull request. In the body: harness, model, date, and how you ran the agent. Say you want the branch kept as `evalcode_*` on this repository (not squash-merged into `main`). Pages only sees branches that exist on [rizafahmi/evalcode](https://github.com/rizafahmi/evalcode).

Do not put held-out tests, secrets, or `.nix-mix` / `_build` / `*.db` in the PR. Milestone commits on the run branch may use `feat(alur): …` ([`docs/decisions.md`](docs/decisions.md)).

---

## License

[MIT](LICENSE) © 2026 Riza Fahmi
