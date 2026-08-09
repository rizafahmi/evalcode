# 02-type-clean — authoring notes

> **Spoiler.** This file spells out the full solution and what the held-out
> tests catch. Never give it to an agent you are measuring.

Validated by hand on 2026-08-03 against Elixir 1.20.2 / OTP 27 (the pinned
`flake.nix` toolchain), inside a throwaway reference run
(`bin/evalcode start 02-type-clean reference manual`), discarded after
validation per Step 10.

## The premise this task rested on

The brief's five violations were written from the Elixir 1.20 release notes
(the `elixir-lang.org` v1.20.0 blog post and `CHANGELOG.md`), not from
observed compiler output. **Verifying each one against the real compiler was
the point of authoring this task**, and it mattered: of the five violations
as originally drafted, only two produced a warning under `mix compile
--force`. The other three had to be rewritten. All five now fire. None were
dropped.

The recurring reason a violation didn't fire as drafted: Elixir 1.20's type
checker is deliberately optimistic about `dynamic()` — confirmed against the
release blog itself ("reporting only verified bugs — typing violations
guaranteed to fail at runtime — while keeping false positives extremely
low") and against `CHANGELOG.md` ("Functions only report violations when
supplied and accepted types are completely disjoint"). A call is flagged
only when **every** possible runtime value of the argument's inferred type
is incompatible. If a union type has even one compatible member (e.g.
`binary() or nil` against a function that accepts `binary()`), the checker
stays silent, because at runtime the value *might* be the compatible one.
The three violations that didn't fire as drafted all had this shape: a
union type flowing into an incompatible call where part of the union was
still valid. The fix in each case was to restructure the code so the
incompatible call sees only the disjoint part of the type, not the whole
union. The intent was to keep each rewrite a genuine instance of the
feature it was labeled as — two of the three (`display_name/1`,
`currency_from/1`) turned out, on external review, to have drifted to a
different mechanism (guard narrowing) than their original label during
that restructuring. See "Fix round 1" below for the correction; the
warnings themselves and the reference solution are unaffected.

## Per-violation: what was planted, what fired, what changed

### 1. `status_label/1` — cross-clause narrowing — fired as drafted

Planted: a `case` on `status` where the second clause (`s ->`) is only
reached when `status` didn't match the `nil` clause above it, so `status`
is narrowed to "not nil" — making the `if is_nil(s)` re-check inside that
clause dead code.

No rewrite needed. Observed warning, verbatim, compiling the overlay as
drafted:

```
warning: comparison between distinct types found:

    s == nil

given types:

    dynamic(not nil) == nil

where "s" was given the type:

    # type: dynamic(not nil)
    # from: lib/warung_web/order_params.ex:13:7
    s

While Elixir can compare across all types, you are comparing across types which are always disjoint, and the result is either always true or always false

type warning found at:
│
14 │         if is_nil(s), do: "unknown", else: to_string(s)
│         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
│
└─ lib/warung_web/order_params.ex:14: WarungWeb.OrderParams.status_label/1
```

Note this is a type-checker-only violation — there's no runtime bug. Both
inputs (`nil` and any other term) already return the right answer, because
the redundant check happens to agree with the narrowed type. It doesn't fail
any held-out test on the dirty module; it's caught purely by the compile
gate.

Reference fix: replace the single clause + redundant re-check with two
function clauses, `status_label(nil)` and `status_label(status)`, so there's
nothing left to compare.

### 2. `display_name/1` — guard narrowing — did NOT fire as drafted, rewritten

Planted (as drafted in the brief): compute `name` from a `case` — `n` when
the map's `:name` is a binary, `nil` otherwise — giving `name` the union
type `dynamic(binary() or nil)`, then call `String.upcase(name)`
unconditionally.

**This produced no warning**, confirmed both in the full app and in an
isolated `elixirc` repro of the identical snippet. Reason: `binary() or
nil` is not *completely* disjoint from `String.upcase/1`'s expected
`binary()` — the `binary()` half of the union is compatible, so under the
"only guaranteed failures" rule the checker stays silent. This isn't a gap
in what was tried — it is **provably unwarnable** under 1.20's stated
disjointness rule: any `case` that produces a "sometimes valid, sometimes
not" union feeding straight into an incompatible call has a compatible
member by construction, so the rule can never fire on it, for any shape of
that kind. A real fix was required, not a different way of writing the
same bug.

Rewrite: kept `name`'s computation exactly as drafted, and added a direct
`is_binary/1` re-check whose two branches both call `String.upcase(name)` —
the same "redundant check, but the wrong branch does the wrong thing" shape
already used by violation 3 (`is_map_key`) in this same module. In the
`else` branch, `name`'s type is narrowed to `dynamic(nil)` alone (not a
union), which **is** completely disjoint from `binary()`.

**Correction (fix round 1 review):** the heading above originally read
"cross-clause narrowing," inherited from the drafted violation this was
rewritten from. That's wrong. This is **guard narrowing** — the same
mechanism as violation 3, not a distinct one — and the `case` above is not
what makes it warn. Proof: deleting it entirely,

```elixir
def f(customer) do
  name = customer
  if is_binary(name), do: String.upcase(name), else: String.upcase(name)
end
```

still warns, on the same line, for the same reason (`is_binary/1` narrows
`name` to "not a binary" in the `else` branch). The reported type differs
slightly — `dynamic(not binary())` here, against `dynamic(nil)` for the
shipped version, because the `case` does still narrow *what specifically*
gets excluded — but the warning is the same class, at the same call site,
fired by the same mechanism: the `if/else`'s own guard narrowing, not the
`case` in front of it.

```elixir
def display_name(customer) do
  name =
    case customer do
      %{name: n} when is_binary(n) -> n
      _ -> nil
    end

  if is_binary(name) do
    String.upcase(name)
  else
    String.upcase(name)
  end
end
```

Observed warning, verbatim, compiling the rewritten overlay:

```
warning: incompatible types given to String.upcase/1:

    String.upcase(name)

given types:

    -dynamic(nil)-

but expected one of:

    binary()

where "name" was given the types:

    # type: dynamic(nil or binary())
    # from: lib/warung_web/order_params.ex:23:10
    name =
      case customer do
        ...
      end

    # type: dynamic(nil)
    # from: lib/warung_web/order_params.ex:29:8
    is_binary(name)

type warning found at:
│
32 │       String.upcase(name)
│              ~
│
└─ lib/warung_web/order_params.ex:32:14: WarungWeb.OrderParams.display_name/1
```

Runtime behavior for the held-out tests is unchanged by the rewrite — both
branches still call `String.upcase(name)`, so `display_name/1` still raises
for a `nil` or non-binary `:name`, exactly as the original drafted version
did.

Reference fix: pattern-match with a guard directly in a `case`, upcasing
only in the binary clause and returning `"ANONYMOUS"` in every other case —
no redundant check, no unconditional call.

### 3. `timeout_for/1` — `is_map_key`/`not_set()` — fired as drafted

Planted: `if not is_map_key(opts, :timeout)` narrows `opts` to
`%{..., timeout: not_set()}` inside the `then` branch — the branch that
knows the key is absent — where `opts.timeout` is then accessed anyway.

No rewrite needed. Observed warning, verbatim:

```
warning: unknown key .timeout in expression:

    opts.timeout

the given type does not have the given key:

    dynamic(%{..., timeout: not_set()})

where "opts" was given the types:

    # type: dynamic(map())
    # from: lib/warung_web/order_params.ex:37:19
    opts

    # type: map()
    # from: lib/warung_web/order_params.ex:37:30
    is_map(opts)

    # type: dynamic(%{..., timeout: not_set()})
    # from: lib/warung_web/order_params.ex:38:12
    is_map_key(opts, :timeout)

type warning found at:
│
39 │       opts.timeout
│            ~~~~~~~
│
└─ lib/warung_web/order_params.ex:39:12: WarungWeb.OrderParams.timeout_for/1
```

The warning correctly points at line 39 — the `then` branch (key known
absent) — and not line 41, the `else` branch (key known present), where the
same `opts.timeout` access is legitimate. The type checker distinguished the
two identically-worded accesses correctly.

Reference fix: `Map.get(opts, :timeout, @default_timeout)`.

### 4. `third_field/1` — tuple arity → `elem/2` bounds — did NOT fire as drafted, rewritten

Planted (as drafted in the brief): `tuple_size(row) < 3` as the guard,
`elem(row, 2)` in the body — index 2 is out of bounds for every tuple that
guard admits (sizes 0, 1, or 2).

**This produced no warning**, confirmed in isolation. Also confirmed the
release blog's own illustrative example doesn't fire either: `tuple_size(x)
< 3` guarding `elem(x, 3)` — the literal shape shown in the blog post —
produced no warning in a standalone repro. Tried `<`, `<=`, and a further
out-of-bounds index (`elem(row, 5)`); none fired. Elixir 1.20's tuple typing
appears to only produce a *precise* fixed-arity tuple type
(`{term(), term()}`) from an **exact** `tuple_size(x) == N` guard — an
inequality guard leaves the tuple's shape unconstrained for `elem/2`
checking purposes, so there's nothing for `elem/2`'s bounds check to compare
against. This is the clearest case in this task of release-note prose
("Elixir will correctly track that the tuple has at most two elements")
not matching observed 1.20.2 behavior for the shape shown.

Rewrite: changed the guard from `tuple_size(row) < 3` to
`tuple_size(row) == 2` — same feature (tuple arity tracking feeding an
`elem/2` bounds check), same out-of-bounds `elem(row, 2)`, but an
exact-arity guard instead of a bound. (A pattern-matched `{_, _} = row`
produces the same precise 2-tuple type and the same warning — tried as a
cross-check — but the guard form was kept since it reads closest to the
drafted violation.)

```elixir
def third_field(row) when tuple_size(row) == 2 do
  elem(row, 2)
end
```

Observed warning, verbatim:

```
warning: expected a tuple with at least 3 elements in Kernel.elem/2:

    elem(row, 2)

the given type does not have the given index:

    dynamic({term(), term()})

where "row" was given the types:

    # type: dynamic({term(), term()})
    # from: lib/warung_web/order_params.ex:47:19
    row

    # type: {term(), term()}
    # from: lib/warung_web/order_params.ex:47:45
    tuple_size(row) == 2

type warning found at:
│
48 │     elem(row, 2)
│     ~
│
└─ lib/warung_web/order_params.ex:48:5: WarungWeb.OrderParams.third_field/1
```

Side effect worth recording: the narrower guard means the dirty module's
`third_field/1` now only has a defined clause for exactly-2-element tuples,
so calling it with a 3-element tuple raises `FunctionClauseError` rather
than the `< 3` guard's `elem/2` bounds error. Either way it raises instead
of returning the third element, which is what the held-out test "returns
the third element when the tuple has one" checks — the dirty module fails
it, same as it would have under the originally drafted `< 3` guard (which
also defines only one clause, also not covering size-3 tuples). The
held-out suite ends up with one more failing test on the dirty module than
the brief's illustrative list mentioned (7 of 12 fail, not the ~4 named as
examples) — a strictly stronger discriminator, not a different one.

Reference fix: two clauses — `tuple_size(row) >= 3` returning `elem(row,
2)`, and a fallback `is_tuple(row)` returning `nil`.

### 5. `currency_from/1` — guard narrowing — did NOT fire as drafted, rewritten

Planted (as drafted in the brief): decode JSON, merge the list-or-map result
into a single `decoded` variable (type `dynamic(list() or map())`), then
call `Map.fetch!(decoded, "currency")` unconditionally.

**This produced no warning** — the same "union has a compatible member"
reason as violation 2, and for the same underlying reason it is **provably
unwarnable**: `map()` is compatible with `Map.fetch!/2`, so a merged
`list()`-or-`map()` value can never be completely disjoint from what
`Map.fetch!/2` accepts, no matter how the merge is written.

Rewrite: dropped the merge. Call `Map.fetch!/2` separately inside each
`case` clause, directly on the clause-local variable, so in the list clause
the argument's type is `list()` alone — not a union — which **is**
completely disjoint from `map()`.

**Correction (fix round 1 review):** the heading above originally read
"`dynamic()` compatibility." That's wrong, and more specifically wrong than
violation 2's mislabeling: this is **guard narrowing**, the identical
mechanism to violation 2's fix rather than a merely-similar one, and
`JSON.decode!/1` turns out not to be load-bearing at all. Proof: replacing
the decode with a bare unconstrained parameter,

```elixir
def f(x) do
  case x do
    list when is_list(list) -> Map.fetch!(list, "currency")
    map when is_map(map) -> Map.fetch!(map, "currency")
  end
end
```

produces a warning whose "given types" and "where list was given the
types" text is **byte-for-byte identical** to the shipped version's
(confirmed by diffing both compiler outputs directly), because
`JSON.decode!/1`'s return type carries no information into the `case` at
all here — the `is_list/1` guard alone does all of the narrowing, on an
argument that was already fully unconstrained either way.

```elixir
def currency_from(payload) when is_binary(payload) do
  case JSON.decode!(payload) do
    list when is_list(list) -> Map.fetch!(list, "currency")
    map when is_map(map) -> Map.fetch!(map, "currency")
  end
end
```

Observed warning, verbatim:

```
warning: incompatible types given to Map.fetch!/2:

    Map.fetch!(list, "currency")

given types:

    -dynamic(empty_list() or non_empty_list(term(), term()))-, binary()

but expected one of:

    map(), term()

where "list" was given the types:

    # type: dynamic(empty_list() or non_empty_list(term(), term()))
    # from: lib/warung_web/order_params.ex:55:7
    list

    # type: empty_list() or non_empty_list(term(), term())
    # from: lib/warung_web/order_params.ex:55:17
    is_list(list)

type warning found at:
│
55 │       list when is_list(list) -> Map.fetch!(list, "currency")
│                                      ~
│
└─ lib/warung_web/order_params.ex:55:38: WarungWeb.OrderParams.currency_from/1
```

Runtime behavior for every held-out `currency_from/1` case is identical to
the originally drafted (merge-based) version — same crash on a list
payload, same crash on a map missing `"currency"`, same successful read
when the key is present. Only the internal structure changed.

Reference fix: a single `case` on the decoded payload — `%{"currency" =>
currency}` returns the value, any other map returns
`{:error, :missing_currency}`, anything else returns
`{:error, :not_an_object}`.

## Verification summary

All five violations fire under `mix compile --force` and, more directly,
under the actual gate command `mix compile --force --warnings-as-errors`
(exit 1, exactly 5 `warning:` lines, all five function names present, zero
`no route path` lines — confirmed this is not the Task 2 route confound).
None were dropped.

Held-out tests against the dirty overlay: **7 of 12 tests fail** (`mix test
test/order_params_test.exs`) — `display_name/1` (2 of 3), `timeout_for/1`
(1 of 2), `third_field/1` (both), `currency_from/1` (2 of 3). This is a
superset of the failures the brief's Step 5 named as examples, not a
different set — every crash the brief predicted still happens; the tuple
guard rewrite in violation 4 additionally makes the "third element" test
fail on the dirty module (`FunctionClauseError` instead of an `elem/2`
bounds error), which the original `< 3` guard would also have done, just
for the same underlying reason (no clause covers a 3-element tuple).

Reference solution (`skeleton/lib/warung_web/order_params.ex`, identical to
what was validated in the reference run): `mix compile --force
--warnings-as-errors` exits 0 with zero warnings; `mix test` passes all 39
tests (12 held-out + 27 pre-existing); `mix format --check-formatted`
passes.

*(These held-out counts are from the original authoring pass. Fix round 1,
below, adds two more held-out tests — 14 held-out + 27 pre-existing = 41 —
after finding two contracts that were under-covered. The five-warning,
zero-route-confound compile-gate result above is unaffected.)*

## Fix round 1 (external review)

An external review of this authored task, run independently against the
same 1.20.2 toolchain, confirmed the crux (all five violations warn, no
function in the dirty module is a red herring, the reference solution
clears both gates) and found two real problems: two of the five violations
were mislabeled, and two of the module's stated contracts were
under-tested. Both are fixed here; nothing in this section changes what
the dirty module warns on or what the reference solution does.

### Mechanism relabeling: four distinct mechanisms, not five

`display_name/1` and `currency_from/1` were headed above as "cross-clause
narrowing" and "`dynamic()` compatibility" respectively — inherited labels
from the *drafted* violations they were rewritten from, not descriptions of
what actually made the *shipped* rewrites warn. Both shipped rewrites fire
from **guard narrowing** — the identical mechanism to each other, and the
same general mechanism violation 3 uses more specifically (via
`is_map_key`/`not_set()`). This was confirmed by deleting the context each
one sits inside (the `case` for #2, the `JSON.decode!/1` call for #5) and
replacing it with a bare unconstrained parameter — both still warn, for #5
with byte-for-byte identical compiler output. Full detail, including the
probe code and diffed output, is inline in sections 2 and 5 above under
"Correction (fix round 1 review)".

**This module's five violations exercise four distinct Elixir 1.20
mechanisms, not five:**

| # | Function | Mechanism | Distinct? |
|---|---|---|---|
| 1 | `status_label/1` | cross-clause narrowing | yes — the only example of this mechanism |
| 2 | `display_name/1` | guard narrowing (`is_binary/1` in an `if/else`) | shared with #5 |
| 3 | `timeout_for/1` | `is_map_key`/`not_set()` | yes — a separately-named inference path in the 1.20 changelog, not generic guard narrowing |
| 4 | `third_field/1` | tuple arity → `elem/2` bounds | yes — the only example of this mechanism |
| 5 | `currency_from/1` | guard narrowing (`is_list/1` in a `case`) | shared with #2 |

Headings above and the overlay's own code comments now say "guard
narrowing" for #2 and #5. #4's heading is renamed from "tuple size bounds"
to "tuple arity → `elem/2` bounds" for the same reason discussed in section
4: the shipped guard is exact-arity (`== 2`), not an inequality bound —
"bounds" alone overstated what 1.20.2 actually tracks here. No runtime
behavior changed anywhere in this correction; it is a labeling fix only,
and it matters because five warnings firing is necessary but is not the
same claim as five distinct capabilities being exercised. Overstating the
count would understate how narrow this benchmark's actual coverage of
1.20's type system is — the thing worth knowing if this task is
re-validated against a future Elixir release and only some mechanisms still
warn.

### Held-out coverage gaps closed

Two contracts in `task.md` were under-covered by the original 12 held-out
tests, letting a plausible partial fix pass every gate:

- **`third_field/1`** — `task.md` says "the third element for a tuple that
  has one," but no held-out test used a tuple with *more* than three
  elements. A fix guarding on `tuple_size(row) == 3` instead of `>= 3`
  (returning `nil` for anything else, including a 4-tuple) passed every
  original held-out test.
- **`currency_from/1`** — `task.md` says a payload that "decodes to
  anything other than an object gives `{:error, :not_an_object}`," but no
  held-out test used a bare JSON scalar (the most common non-object shape
  after a list). A fix whose `case` has a `list when is_list(list) ->
  {:error, :not_an_object}` clause but no catch-all raises
  `CaseClauseError` on a scalar payload like `"42"` instead of returning
  the contracted error tuple, and no original test caught it.

Two assertions added, one per gap, exact equality like every other
assertion in the file:

```elixir
assert OrderParams.third_field({:a, :b, :c, :d}) == :c
assert OrderParams.currency_from("42") == {:error, :not_an_object}
```

Verified against a reconstruction of exactly the partial-fix shape
described above (`third_field/1` guarded on `== 3` with a `nil` fallback;
`currency_from/1`'s `case` given a `list when is_list(list) -> {:error,
:not_an_object}` clause and no catch-all) in a throwaway run: that
partial fix compiles clean (`mix compile --force --warnings-as-errors`,
exit 0, zero warnings) and **passes all 12 original held-out tests** —
exactly the false "complete" result the review flagged — but **fails both
new assertions** (`12/14 passed`; the two failures are exactly the two new
tests — `third_field({:a, :b, :c, :d})` returns `nil` instead of `:c`, and
`currency_from("42")` raises `CaseClauseError` instead of returning the
error tuple). Restoring the actual reference solution in the same run
passes all 14 held-out tests, all 41 tests project-wide (14 held-out + 27
pre-existing), with `mix compile --force --warnings-as-errors` still
exiting 0 and `mix format --check-formatted` still clean. No change was
needed to the reference solution — it already satisfied both contracts.

## Not tested, deliberately

`status_label/1`'s violation has no runtime consequence — see above. It's
intentionally the one violation in this module that the held-out tests
cannot catch; only the compile gate catches it. That's fine: the task's
"done means" requires both a clean compile *and* passing tests, so a model
that fixes only the four runtime bugs and leaves `status_label/1`'s dead
code in place still fails the compile gate.

## Held-out file and module naming

The held-out file is `holdout/holdout_order_params_test.exs` and its module is
`WarungWeb.Holdout.OrderParamsTest`. Both carry the prefix on purpose.

This task tells the model, in `task.md`, exactly which module to fix:
`lib/warung_web/order_params.ex`. The single most predictable extra step after
fixing it is writing `test/warung_web/order_params_test.exs` containing
`defmodule WarungWeb.OrderParamsTest`. That is precisely what the held-out
module used to be called, in a file called `order_params_test.exs`. When
`grade` copied the held-out file into `test/`, the run failed to compile:

```
error: cannot define module WarungWeb.OrderParamsTest because it is currently
being defined in test/order_params_test.exs:1
```

`mix test` exits non-zero, so a model that solved the task **and then did the
diligent thing** scored `completed=no`. Reproduced by planting exactly that
model-authored test in a run and grading it; after the rename the same run
compiles and scores on merit.

The rule for every future task: held-out modules go under a `Holdout`
namespace and held-out filenames start with `holdout_`, so neither the module
name nor the path can clash with anything a model would naturally write.

## Test-count floor

`tasks/02-type-clean/grading.conf` sets `min_tests=41` — 27 skeleton tests plus
14 held-out. Verified by running the reference solution, not by counting by
hand. If the held-out file gains or loses a test, that number has to move with
it.
