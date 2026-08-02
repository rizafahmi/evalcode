# evalcode — Design

**Date:** 2026-08-03
**Status:** Approved, pending implementation plan
**Supersedes:** `2026-08-02-evalcode-design.md` (12 tasks, escript harness, two tracks — too large to start)

## Problem

When a new model is released, there is no repeatable way to answer "how good is this at *my* kind of work?" Public benchmarks measure Python and JavaScript on problems every model has memorised.

`ariya/hono-saas-starter` solves this with a skeleton Hono app, one task ("add basic auth"), and a README table of duration and cost per model. This project takes that shape and changes three things:

1. **Phoenix LiveView.** Stateful server-rendered UI is a different discipline from request/response, and it is what the operator actually builds.
2. **Elixir 1.20's gradual type system.** It shipped 2026-06-03. No public benchmark tests it and most models have never seen it.
3. **Held-out tests.** A duration-and-cost table cannot distinguish "done" from "looks done." One extra test file per task, copied in only at grading, closes that gap cheaply.

## Approach

Human-driven. The script copies a skeleton into a fresh directory and hands over a task. The operator opens their own coding agent — with whatever model and harness are under test — and works it. The script then copies in tests the agent never saw, runs them, and appends a row to `RESULTS.md`.

The script never calls a model API. It copies directories, runs `mix test`, and prints a table row.

## Scope

**In scope:**

- One skeleton Phoenix 1.8 LiveView app (`Warung`)
- Two tasks
- A shell script with two subcommands: `start`, `grade`
- `RESULTS.md` — a markdown table, appended to
- A nix flake and `.envrc` pinning the toolchain

**Deliberately excluded**, each returning only when doing it by hand hurts:

| Excluded | Comes back when |
|---|---|
| An escript harness | The shell script exceeds what shell should do |
| `verify` (fail-to-pass validation) | Enough tasks that authoring drift stops being noticeable |
| `results.jsonl` | The markdown table stops being queryable |
| Tracks and per-category breakdowns | There are enough tasks to have categories |
| A typing primer and `--docs` flag | There is evidence models fail on missing 1.20 knowledge rather than reasoning |
| Automatic token capture | Manual cost entry becomes the bottleneck |

## Toolchain

| Component | Version |
|---|---|
| Elixir | 1.20.2 (pinned via flake) |
| Erlang/OTP | 27 |
| Phoenix | 1.8, LiveView 1.1 |
| Database | SQLite via `ecto_sqlite3` |
| Node | 22, for esbuild and tailwind |
| Harness | `bash` |

`flake.nix` follows the shape already used in `~/code/learn_loop`: `beam.packages.erlang_27`, `elixir_1_20`, `nodejs_22`, a `shellHook` asserting the versions, `MIX_HOME`/`HEX_HOME` under the project root. `.envrc` is `use flake`.

Because `runs/` sits inside the project, direnv walks up and loads the root `.envrc` automatically — a workspace shell has the correct Elixir with no per-run setup, and the hex cache is shared across runs.

`mix test` does not need built assets, so grading never depends on esbuild or tailwind. Node is present only so the agent can run the dev server and look at the page.

Elixir 1.20 has **no user-facing type annotation syntax**; explicit type signatures do not exist in this version. The type task is about making code survive the inference engine, never about writing signatures.

## Layout

```
evalcode/
├── flake.nix
├── .envrc
├── bin/evalcode              # bash, two subcommands
├── skeleton/                 # Phoenix 1.8 LiveView app, compiles clean, tests pass
├── tasks/
│   ├── 01-live-orders/
│   │   ├── task.md           # the prompt
│   │   └── holdout/          # tests copied in at grade only
│   └── 02-type-clean/
│       ├── task.md
│       ├── overlay/          # replaces skeleton files → type-dirty start state
│       └── holdout/
├── RESULTS.md                # the table
└── runs/                     # gitignored
    └── <run-id>/             # the operator opens their agent HERE
```

A task is a directory holding a prompt, an optional overlay, and held-out tests. `overlay/` mirrors the skeleton tree and replaces files at the same relative path; task 01 needs none.

**Isolation:** the agent never opens `evalcode/`. It opens `runs/<run-id>/`, which contains only the skeleton, the task overlay, and `TASK.md`. Held-out tests and other tasks stay outside it.

## The skeleton: `Warung`

`mix phx.new warung --database sqlite3 --no-mailer` — HTML, assets, and LiveView included. Small on purpose:

- `Warung.Catalog` — `Product` (sku, name, price as `Decimal`, stock)
- `Warung.Orders` — `Order`, `OrderItem`, `create_order/1`, `list_orders/0`
- `WarungWeb.OrderLive.Index` — a LiveView listing orders, with a form that places one
- A passing test suite; compiles clean under `mix compile --warnings-as-errors`

Orders already work and the page already renders. Both tasks build on that rather than reconstructing it.

Held-out tests use `Phoenix.LiveViewTest` — `live/2`, `render_submit/2`, `has_element?/2` — not a wrapper library. The benchmark should not measure whether a model knows `phoenix_test`.

## Task 01 — `01-live-orders`

**Make the orders dashboard live.** An order placed in one browser session appears immediately in every other connected session, without a refresh.

LiveView-distinctive and not solvable by a generator. It needs PubSub subscription in `mount/3`, a broadcast on order creation, `handle_info/2`, and a stream update.

`task.md` specifies the happy path: two sessions open, one places an order, the other sees it. It does not specify the edge cases.

Held-out tests cover what `task.md` leaves out:

|  | expected |
|---|---|
| Order created by calling `Orders.create_order/1` directly, no LiveView involved | Still appears in connected sessions |
| The session that placed the order | Exactly one row, not two |
| Disconnected mount (a plain `get`) | Renders existing orders, does not crash |
| Two orders in sequence | Both appear, correct count |
| Existing order tests | Still pass |

The first row is the architectural discriminator. Broadcasting from `handle_event` passes every visible test and fails it — the broadcast belongs in the `Orders` context so it fires regardless of who created the order. The second row catches the other naive shape: broadcasting to all subscribers *and* updating locally, which double-inserts for the acting client.

**Why this task and not "add auth":** `mix phx.gen.auth` exists, so authentication in Phoenix measures whether a model remembers a generator name.

**Alternatives considered.** Live search with URL state via `push_patch` — heavily represented in tutorials. File uploads with `allow_upload` — less memorised, but its failure modes are "did you read the docs" rather than "did you reason." A `start_async` price lookup — good, but thinner held-out surface.

## Task 02 — `02-type-clean`

**Make the code survive Elixir 1.20's type checker.** `overlay/` replaces a LiveView and its helper module with versions carrying four planted violations, one per inference capability:

| violation | 1.20 feature |
|---|---|
| A `case` that re-checks `nil` after the first clause eliminated it (dead code), *and separately* a real `nil` reaching `String.upcase/1` (a verified bug) | cross-clause narrowing |
| A `handle_event` branch guarded by `not is_map_key(socket.assigns, :filter)` that then reads `socket.assigns.filter` | `is_map_key` / `not_set()` |
| `elem(x, 2)` under a `tuple_size(x) < 3` guard | tuple size bounds |
| Decoded JSON passed to `Map.fetch!/2` with disjoint types | `dynamic()` compatibility |

Socket assigns are plain maps, so the `not_set()` violation sits naturally in LiveView code rather than being contrived.

The first row is the discriminator. Both look like nil-safety problems and require opposite fixes: one check must be deleted, the other must be made real. Treating them alike fails either way.

**Passing requires all three of:**

1. `mix compile --warnings-as-errors` succeeds
2. Held-out behaviour tests pass
3. No `@compile` or `@dialyzer` suppression attributes were added

The third is checked by diffing against the start state. The gate invites shortcuts, and each has a counter:

| shortcut | caught by |
|---|---|
| Delete the error branch to collapse the union | Held-out tests exercise the error path |
| Add a suppression attribute | Diff scan |
| Launder the type through `Map.get/2` into `any()` | Held-out tests assert the specific error tuples still surface |

## The script

```bash
bin/evalcode start <task-id> <model> <harness>
bin/evalcode grade <run-id> [--cost 3.39] [--duration 12m]
```

**`start`** copies `skeleton/` to `runs/<run-id>/`, applies `tasks/<id>/overlay/` if present, writes `TASK.md`, runs `mix deps.get` and `mix ecto.setup`, and prints the path. The run id is `<date>-<model>-<task>`, e.g. `2026-08-03-opus5-01`.

Before handing over, `start` snapshots the pristine start state to `runs/<run-id>.base/` and writes `runs/<run-id>.meta` with the task id, model, harness, and start time. Everything `grade` needs to build a table row is captured up front, so `grade` takes only a run id.

**`grade`** copies `tasks/<id>/holdout/` into the run's test directory, runs `mix test`, runs `mix compile --warnings-as-errors`, diffs the run against its `.base/` snapshot and greps that diff for added `@compile` / `@dialyzer` attributes, then prints a markdown row and appends it to `RESULTS.md`.

Cost is entered by hand from the agent's own reporting — `/cost` in Claude Code, equivalents elsewhere. It takes two seconds and beats building a transcript parser.

## Results

`RESULTS.md` holds one table:

| task | model | harness | completed | duration | cost | compile |
|---|---|---|---|---|---|---|
| 01 | claude-opus-5 | claude-code | yes | 14m | $2.10 | clean |
| 02 | claude-opus-5 | claude-code | no | 22m | $4.35 | 2 warnings |

`completed` is held-out tests passing — plus a clean compile for task 02. **Harness is a first-class column**: you never run a model, you run a model inside an agent, and the same model scores differently across Claude Code, Codex, and OpenCode.

## Testing

The skeleton's own suite is the regression check: it must pass and compile clean before any task is authored.

Each task is validated by hand, once, at authoring time — confirm the start state fails the held-out tests, then solve it yourself and confirm they pass. This is what `verify` automated in the previous design. At two tasks, doing it by hand is correct; the automation earns its way back when a skeleton change could silently break a task without anyone noticing.

## Known limitations

**The clean-compile gate is unverified against LiveView.** Task 02 assumes a stock Phoenix 1.8 LiveView app compiles clean under Elixir 1.20 with `--warnings-as-errors`. HEEx templates compile to generated functions, and the 1.20 release notes acknowledge known inference false positives. If macro-generated code produces warnings the operator cannot fix, the global gate is unusable and must narrow to warnings originating in the task's own modules. **This is the first thing the implementation plan checks**, because it is the one assumption that can invalidate task 02.

**Wall-clock timing includes operator idle time.** `duration` runs from `start` to `grade`. Use `--duration` to override with the agent's own reported figure when it gives one.

**Two tasks is not a benchmark, it is a probe.** Task-level differences between models are noise. The purpose of v1 is to find out whether this measurement teaches you anything at all before investing in more tasks — and, specifically, whether the type task discriminates more sharply than the LiveView task. That answer determines where task three onward goes.

**The skeleton is synthetic.** It is cleaner than real code, so it measures capability on well-structured Elixir. That is a floor, not a prediction of behaviour in a messy repository.

**Contamination.** If this repository is ever published, future models may train on it. Keeping it private preserves its value.

## Implementation sequence

1. `flake.nix`, `.envrc`, repository skeleton
2. Generate a stock Phoenix 1.8 LiveView app and **confirm it compiles clean under Elixir 1.20 with `--warnings-as-errors`**. If it does not, narrow the task 02 gate to per-module warnings before going further.
3. The `Warung` skeleton — orders context, `OrderLive.Index`, passing suite
4. `bin/evalcode` — `start` and `grade`
5. Task 01, validated by hand end to end
6. Task 02, validated by hand end to end
7. First real run against a model you already have access to

Step 7 is the point of the whole thing. Everything after it is informed by data instead of by guessing.