# evalcode

A private benchmark for coding models, run against a Phoenix LiveView codebase.

Each round: pick a task, start a run, work it in your own coding agent with the
model you want to measure, then grade it. Grading uses tests the agent never saw.

## Setup

```bash
direnv allow      # or: nix develop
```

## Running a round

```bash
bin/evalcode start 01-live-orders opus5 claude-code
```

That prints a workspace path. Open your coding agent there and read `TASK.md`.
Do not open this repository in the agent — the held-out tests live here.

When the agent is done:

```bash
bin/evalcode grade 2026-08-03-opus5-01 --cost 2.10
```

Cost comes from your agent's own reporting — `/cost` in Claude Code. If the agent
reports its own working time, pass `--duration 12m` too; otherwise duration is
wall-clock from `start` to `grade` and includes any time you spent away.

The row is appended to `RESULTS.md`.

## Tasks

| id | what it measures |
|---|---|
| `01-live-orders` | Phoenix LiveView, PubSub, streams — and whether the broadcast is put in the right layer |
| `02-type-clean` | Elixir 1.20 gradual type inference, and whether the fix is real or a suppression |

## Adding a task

A task is a directory under `tasks/` with `task.md`, a `holdout/` directory of
tests, and optionally an `overlay/` directory that replaces skeleton files.
Validate a new task by hand: confirm its held-out tests fail on the untouched
skeleton, then solve it yourself and confirm they pass. Record both in `NOTES.md`.
