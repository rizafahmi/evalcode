# Shipping `skeleton/AGENTS.md` is deliberate — and it was edited

`skeleton/AGENTS.md` is the file `mix phx.new` 1.8.0 generates. It ships with
every benchmark run: the model under test reads it. That is the decision, taken
deliberately, because it is what a real Phoenix 1.8 project a model is dropped
into actually contains, and a fixture that hides it would be measuring
something that does not happen in the field.

The consequence is that the file's claims are part of the instrument. A false
claim in it is a defect in the benchmark, not a cosmetic issue — a model that
follows the fixture's own written instructions and is then marked down for it
produces a wrong number with a plausible explanation attached.

Three things in the generated file were false here. All three are fixed. If the
skeleton is ever regenerated from `mix phx.new`, **the originals will come
back** and have to be re-fixed.

## 1. `mix precommit` could not fail

Generated `mix.exs`:

```elixir
precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
```

`--warning-as-errors` is singular. Mix does not recognise the switch, ignores
it silently, and `mix compile` exits 0 with every warning outstanding — so the
whole alias exits 0. Meanwhile `AGENTS.md`'s first project guideline is:

> Use `mix precommit` alias when you are done with all changes and fix any
> pending issues

Task 02 is scored on `mix compile --force --warnings-as-errors` exiting 0. A
model that finished the task, ran `mix precommit` exactly as instructed, and
got a green light, could still be sitting on all five type warnings. Verified
before the fix: `mix precommit` on the dirty task-02 overlay exited 0.

Fixed to `--warnings-as-errors` (plural). It now exits 1 on the dirty overlay.

## 2. `Req` was claimed to be available

Generated `AGENTS.md`:

> Use the already included and available `:req` (`Req`) library for HTTP
> requests…  Req is included by default and is the preferred HTTP client for
> Phoenix apps

`:req` is not a dependency of this project — it went with Swoosh under
`mix phx.new --no-mailer` — and is absent from `mix.exs`, `mix.lock` and
`deps/`. Runs are offline (`deps/` is copied into the workspace precisely so
`start` does not need the network), so a model taking the instruction at face
value cannot even `mix deps.get` its way out.

The bullet now states that there is no HTTP client dependency and that adding
one will not resolve.

## 3. The `<Layouts.app>` rule contradicted the fixture

Generated `AGENTS.md`:

> **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>`
> which wraps all inner content

`skeleton/lib/warung_web/live/order_live/index.ex` did not do this. A fixture
that breaks its own stated conventions teaches the model that the conventions
are optional, and leaves a model that follows them making a change nobody
asked for.

Resolved by making the fixture follow the rule: `OrderLive.Index`'s `render/1`
is now wrapped in `<Layouts.app flash={@flash}>`. This was the preferred
direction — a fixture that follows its own conventions is the better
instrument, and the alternative (deleting the guideline) would have meant
editing more of the generated file than necessary.

Re-verified after the change, since it alters rendered markup:

- `mix compile --force --warnings-as-errors` on the skeleton: exit 0, clean
- `mix format --check-formatted`: clean
- skeleton suite: 27 passed
- task 01's held-out tests, including the row-order assertion: pass on the
  reference solution, fail on the untouched start state
- task 02's held-out tests: unaffected (they do not render)

## What was *not* changed

Everything else in the generated file. The Elixir/Phoenix/Ecto/HEEx/LiveView
guideline blocks are left verbatim, including the `usage-rules` markers, so a
future regeneration diffs cleanly against this version and the three fixes
above are the only deltas to re-apply.
