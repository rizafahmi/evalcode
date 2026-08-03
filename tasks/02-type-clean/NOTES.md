# 02-type-clean — authoring notes

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
still valid. The fix in each case was to restructure the code — without
changing which 1.20 feature it exercises — so the incompatible call sees
only the disjoint part of the type, not the whole union.

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

### 2. `display_name/1` — cross-clause narrowing — did NOT fire as drafted, rewritten

Planted (as drafted in the brief): compute `name` from a `case` — `n` when
the map's `:name` is a binary, `nil` otherwise — giving `name` the union
type `dynamic(binary() or nil)`, then call `String.upcase(name)`
unconditionally.

**This produced no warning**, confirmed both in the full app and in an
isolated `elixirc` repro of the identical snippet. Reason: `binary() or
nil` is not *completely* disjoint from `String.upcase/1`'s expected
`binary()` — the `binary()` half of the union is compatible, so under the
"only guaranteed failures" rule the checker stays silent. The call might
succeed, so it's not flagged, even though it provably fails for half the
domain.

Rewrite: kept `name`'s computation exactly as drafted, and added a direct
`is_binary/1` re-check whose two branches both call `String.upcase(name)` —
the same "redundant check, but the wrong branch does the wrong thing" shape
already used by violation 3 (`is_map_key`) in this same module. In the
`else` branch, `name`'s type is narrowed to `dynamic(nil)` alone (not a
union), which **is** completely disjoint from `binary()`.

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

### 4. `third_field/1` — tuple size bounds — did NOT fire as drafted, rewritten

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
`tuple_size(row) == 2` — same feature (tuple size bounds), same
out-of-bounds `elem(row, 2)`, but an exact-arity guard instead of a bound.
(A pattern-matched `{_, _} = row` produces the same precise 2-tuple type and
the same warning — tried as a cross-check — but the guard form was kept
since it reads closest to the drafted violation and to "tuple size bounds"
as a named feature.)

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

### 5. `currency_from/1` — `dynamic()` compatibility — did NOT fire as drafted, rewritten

Planted (as drafted in the brief): decode JSON, merge the list-or-map result
into a single `decoded` variable (type `dynamic(list() or map())`), then
call `Map.fetch!(decoded, "currency")` unconditionally.

**This produced no warning** — the same "union has a compatible member"
reason as violation 2. `map()` is compatible with `Map.fetch!/2`, so the
`list()` half being wrong isn't enough to trip the "completely disjoint"
rule once the two are merged into one variable.

Rewrite: dropped the merge. Call `Map.fetch!/2` separately inside each
`case` clause, directly on the clause-local variable, so in the list clause
the argument's type is `list()` alone — not a union — which **is**
completely disjoint from `map()`.

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

## Not tested, deliberately

`status_label/1`'s violation has no runtime consequence — see above. It's
intentionally the one violation in this module that the held-out tests
cannot catch; only the compile gate catches it. That's fine: the task's
"done means" requires both a clean compile *and* passing tests, so a model
that fixes only the four runtime bugs and leaves `status_label/1`'s dead
code in place still fails the compile gate.
