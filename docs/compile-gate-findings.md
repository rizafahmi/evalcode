# Compile-gate viability finding

Spike for Task 2 of the evalcode build plan. Question: does a stock Phoenix
1.8 LiveView app compile clean under Elixir 1.20 with
`--warnings-as-errors`, so that Task 02's grading gate (`mix compile
--force --warnings-as-errors` exiting 0) can be applied to the whole
project rather than narrowed to specific paths?

## Environment

Confirmed inside `nix develop` before running anything else:

```
$ elixir --version
Erlang/OTP 27 [erts-15.2.7.9] [source] [64-bit] [smp:10:10] [ds:10:10:10] [async-threads:1] [jit]
Elixir 1.20.2 (compiled with Erlang/OTP 27)
```

## Steps run

All commands run inside `nix develop --command bash -c '...'` from the
pinned shell (`flake.nix` in this repo), using the repo's own
`MIX_HOME`/`HEX_HOME` (`.nix-mix`, `.nix-hex`).

```bash
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new 1.8.0 --force
```

```bash
mkdir -p /tmp/evalcode-gatecheck && cd /tmp/evalcode-gatecheck
mix phx.new gatecheck --database sqlite3 --no-mailer --install
```

Generated app dependency versions (from `mix.lock`):

- `phoenix` 1.8.9
- `phoenix_live_view` 1.1.32

```bash
cd gatecheck
mix compile --force --warnings-as-errors
```

## Result

**Exit code: 0.**

Full captured output of the app's own compilation step (`--force` recompiled
all of the app's 14 `.ex` files, including the HEEx-embedding modules
`core_components.ex`, `layouts.ex`, and `page_html.ex`, which pull in
`layouts/root.html.heex` and `page_html/home.html.heex` via
`embed_templates`):

```
Compiling 14 files (.ex)
Generated gatecheck app
exit=0
```

No warnings were emitted for any of the app's own modules. There were no
type-inference warnings, no unused-variable warnings, nothing — the log
above is the complete output for the `gatecheck` app's compilation.

### Note: warnings exist in dependency compilation, but do not affect the gate

To rule out a stale-build artifact producing a false "clean" result, the
compile was repeated from a fully deleted `_build/` (forcing Phoenix,
LiveView, Ecto, Gettext, Bandit, etc. to recompile from source alongside
the app):

```bash
rm -rf _build && mix compile --force --warnings-as-errors
```

This run again exited 0, but this time it also compiled all dependencies,
several of which do emit warnings (e.g. `telemetry_metrics`,
`phoenix_template`, `dns_cluster`, `gettext`, `phoenix_live_dashboard`).
These are warnings in third-party library code that ships as pre-published
Hex packages, not in the `gatecheck` app's own `lib/`. Mix's
`--warnings-as-errors` flag applies only to the compilation of the current
project, not to `mix deps.compile` — dependency warnings are printed but do
not cause `mix compile --warnings-as-errors` to fail, and the exit code was
0 both times. This is consistent, not flaky: the app's own code compiled
warning-free in both runs; the only difference between runs was whether
already-compiled dependencies needed to be rebuilt, and dependency warnings
never affect the gate's exit code regardless.

No warning ever appeared inside `lib/gatecheck/` or `lib/gatecheck_web/`
(the analogue of `lib/warung/` and `lib/warung_web/` in the real benchmark
app) in either run.

## Decision

> **Decision: global gate viable.** A stock Phoenix 1.8 LiveView app
> compiles clean under Elixir 1.20.2 with `--warnings-as-errors`. Task 02
> grades on whole-project compile.

This follows directly from the captured output above: the command
specified by the gate (`mix compile --force --warnings-as-errors`) exited
0 against a stock, unmodified `mix phx.new gatecheck --database sqlite3
--no-mailer --install` app, with zero warnings anywhere in the app's own
source, and the result was reproduced across two independent compiles
(warm build and from a fully deleted `_build/`). No changes were made to
the generated app to obtain this result.

## Caveat

This app does not contain a LiveView *page* under a `live/.../` route
(stock `phx.new` without `--live` doesn't scaffold one), so it does not
exercise `live/*_live.ex` modules specifically. It does exercise Phoenix
1.8's default HEEx-heavy scaffolding (`core_components.ex`'s
attr/slot-annotated function components, `layouts.ex`, and
`embed_templates`-based `.heex` compilation), which is the same
macro-generated-code category the risk in the plan is concerned about, and
none of it produced a warning. If Task 3's actual `order_live/` LiveView
modules turn out to trigger inference warnings HEEx-only scaffolding does
not, that would be new information contradicting this finding, and Task 7
grading should be revisited if so.
