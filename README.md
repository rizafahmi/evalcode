# evalcode

A private benchmark for coding models, run against a Phoenix LiveView codebase.

Each round: pick a task, start a run, work it in your own coding agent with the
model you want to measure, then grade it. Grading uses tests the agent never saw.

## Setup

```bash
direnv allow      # or: nix develop
```

Both subcommands refuse to run outside the pinned devshell. Task 02 is scored on
a warning class that only exists in Elixir 1.20's type checker; under 1.18 its
untouched start state compiles clean and would score as completed work.

## Running a round

```bash
bin/evalcode start 01-live-orders opus5 claude-code
```

That prints a workspace path. Open your coding agent there and read `TASK.md`.
Do not open this repository in the agent — the held-out tests live here.

Starting the same model on the same task twice in one day is fine: the second
run gets a `-2` suffix. Within-model variance is worth measuring.

When the agent is done:

```bash
bin/evalcode grade 2026-08-03-opus5-01 --cost 2.10
```

Cost comes from your agent's own reporting — `/cost` in Claude Code. If the agent
reports its own working time, pass `--duration 12m` too; otherwise duration is
wall-clock from `start` to `grade` and includes any time you spent away.
`--duration` must look like `12m` and `--cost` like `2.10`; anything else is
refused rather than written into the table.

The row is appended to `RESULTS.md`. A graded run is marked with a
`runs/<id>.graded` file and grading it again is refused — pass `--regrade` if you
really mean to.

## What `completed` means

A run is `completed=yes` only when all of these hold:

- `mix test` passes with the held-out tests copied in
- at least `min_tests` tests actually ran (see `grading.conf` below) — an exit
  code of 0 says nothing about how many tests were left
- no `@compile` / `@dialyzer` suppression attributes were added
- `mix compile --force --warnings-as-errors` exits 0, for tasks whose
  `grading.conf` sets `requires_clean_compile=yes`

`RESULTS.md`'s last column, `notes`, carries the reason a row is not completed —
`suppressions added`, `only 10 of 32 tests ran`, `tests failed`,
`compile failed`. It is empty on a pass. Without it the table cannot tell a
model that tried and failed from one that silenced the checker.

## Tasks

| id | what it measures |
|---|---|
| `01-live-orders` | Phoenix LiveView, PubSub, streams — and whether the broadcast is put in the right layer |
| `02-type-clean` | Elixir 1.20 gradual type inference, and whether the fix is real or a suppression |

## Adding a task

A task is a directory under `tasks/` with `task.md`, a `grading.conf`, a
`holdout/` directory of tests, and optionally an `overlay/` directory that
replaces skeleton files.

`grading.conf` is shell-sourced by `grade` and is required — a task without one
is refused by both `start` and `grade` rather than graded with no gates:

```
min_tests=32               # skeleton tests + held-out tests, counted by running
requires_clean_compile=no  # yes makes --warnings-as-errors part of `completed`
```

Rules for the held-out tests:

- **Namespace the modules under `Holdout`** — `WarungWeb.Holdout.MyThingTest` —
  and prefix the filenames `holdout_`. A model that solves the task and then
  writes the obvious test for the module it just changed will otherwise collide
  with a held-out module of the same name, and the whole run fails to compile:
  `completed=no` for a model that did the work and then did the diligent thing.
- **Any test module that touches the database must be `async: false`.** SQLite
  locks the whole database file; async writers flake about one run in thirty,
  which reads as a model failure.

Validate a new task by hand: confirm its held-out tests fail on the untouched
skeleton, then solve it yourself and confirm they pass. Confirm `min_tests`
matches what actually runs. Record all of it in `NOTES.md`.
