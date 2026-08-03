#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok   $label"
  else
    echo "  FAIL $label"
    echo "         expected: $expected"
    echo "         actual:   $actual"
    FAILED=1
  fi
}

EVALCODE_LIB_ONLY=1 source "$ROOT/bin/evalcode"

# Each case calls new_fixture as `fx="$(new_fixture ...)"`, which forks a
# subshell to capture its stdout -- so a variable the function sets internally
# (a single FIXTURE_TMP, or an array appended with FIXTURE_TMPS+=(...)) is
# mutated only in that subshell's copy and vanishes with it; the parent shell
# never sees it, and the EXIT trap finds nothing to remove. Establishing one
# parent directory here, directly in the top-level shell rather than inside a
# function invoked through $(...), sidesteps that: new_fixture only ever needs
# to create a subdirectory of an already-known path, and a single rm -rf on
# that parent recursively removes every fixture regardless of how many
# new_fixture calls happened.
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/evalcode-fx.XXXXXX")"

fixture_cleanup() { rm -rf "$FIXTURE_ROOT"; }
trap fixture_cleanup EXIT

echo "run_id_for"
assert_eq "2026-08-03-opus5-01" "$(run_id_for 2026-08-03 opus5 01-live-orders)" "strips the task slug"
assert_eq "2026-08-03-opus5-02" "$(run_id_for 2026-08-03 opus5 02-type-clean)" "handles the second task"

echo "require_elixir_120"
mkdir -p "$FIXTURE_ROOT/elixir120" "$FIXTURE_ROOT/elixir118" "$FIXTURE_ROOT/elixir-none"
cat > "$FIXTURE_ROOT/elixir120/elixir" <<'STUB'
#!/usr/bin/env bash
printf 'Erlang/OTP 27 [erts-15.2.7.9] [source] [64-bit]\n\nElixir 1.20.2 (compiled with Erlang/OTP 27)\n'
STUB
cat > "$FIXTURE_ROOT/elixir118/elixir" <<'STUB'
#!/usr/bin/env bash
printf 'Erlang/OTP 28 [erts-16.4.0.3] [source] [64-bit]\n\nElixir 1.18.4 (compiled with Erlang/OTP 28)\n'
STUB
chmod +x "$FIXTURE_ROOT/elixir120/elixir" "$FIXTURE_ROOT/elixir118/elixir"

( PATH="$FIXTURE_ROOT/elixir120:$PATH"; require_elixir_120 ) >/dev/null 2>&1
assert_eq "0" "$?" "accepts Elixir 1.20.x"
( PATH="$FIXTURE_ROOT/elixir118:$PATH"; require_elixir_120 ) >/dev/null 2>&1
assert_eq "1" "$?" "refuses Elixir 1.18.x"
( PATH="$FIXTURE_ROOT/elixir-none:/usr/bin:/bin"; require_elixir_120 ) >/dev/null 2>&1
assert_eq "1" "$?" "refuses when there is no elixir on PATH"

echo "evalcode_status"
assert_eq "yes" "$(evalcode_status no pass clean no)" "passes on tests alone when no compile gate"
assert_eq "yes" "$(evalcode_status no pass "2 warnings" no)" "ignores compile warnings when no compile gate"
assert_eq "no"  "$(evalcode_status no fail clean no)" "fails on failing tests"
assert_eq "no"  "$(evalcode_status no pass clean yes)" "fails when suppressions were added"
assert_eq "yes" "$(evalcode_status yes pass clean no)" "passes on tests plus clean compile"
assert_eq "no"  "$(evalcode_status yes pass "1 warnings" no)" "fails on any warning when gated"
assert_eq "no"  "$(evalcode_status yes fail clean no)" "gated task fails on failing tests"
assert_eq "no"  "$(evalcode_status yes pass clean yes)" "gated task fails when suppressions were added"

echo "format_row"
assert_eq "| 01-live-orders | opus5 | claude-code | yes | 14m | \$2.10 | clean |  |" \
  "$(format_row 01-live-orders opus5 claude-code yes 14m 2.10 clean "")" "renders a full row with empty notes"
assert_eq "| 01-live-orders | opus5 | claude-code | no | 9m | — | clean | tests failed |" \
  "$(format_row 01-live-orders opus5 claude-code no 9m "" clean "tests failed")" \
  "renders an em dash for missing cost and a reason in notes"

echo "valid_duration / valid_cost"
valid_duration 14m;            assert_eq "0" "$?" "accepts 14m"
valid_duration 0m;             assert_eq "0" "$?" "accepts 0m"
valid_duration not-a-duration; assert_eq "1" "$?" "rejects a word"
valid_duration 14;             assert_eq "1" "$?" "rejects a bare number"
valid_duration "14m ";         assert_eq "1" "$?" "rejects trailing junk"
valid_cost 2.10;               assert_eq "0" "$?" "accepts 2.10"
valid_cost 2;                  assert_eq "0" "$?" "accepts a whole number"
valid_cost '$2.10';            assert_eq "1" "$?" "rejects a leading dollar sign"
valid_cost "free";             assert_eq "1" "$?" "rejects a word"

echo "test_count_from"
count_log() { printf '%s\n' "$1" > "$FIXTURE_ROOT/count.log"; test_count_from "$FIXTURE_ROOT/count.log"; }
assert_eq "27" "$(count_log 'Result: 27 passed')" "reads a clean pass"
assert_eq "3"  "$(count_log 'Result: 2/3 passed')" "reads the total, not the passing count"
assert_eq "2"  "$(count_log 'Result: 2 passed, 1 skipped')" "skipped tests did not run"
assert_eq "0"  "$(count_log 'Result: 0 tests, 32 excluded')" "excluding everything counts as zero"
assert_eq "27" "$(count_log '27 tests, 0 failures')" "understands the pre-1.19 summary"
count_log 'There are no tests to run' >/dev/null 2>&1
assert_eq "1" "$?" "an unparseable log fails rather than reporting a count"
test_count_from "$FIXTURE_ROOT/does-not-exist.log" >/dev/null 2>&1
assert_eq "1" "$?" "a missing log fails rather than reporting a count"

echo "elapsed_minutes"
assert_eq "14m" "$(elapsed_minutes 2026-08-03T09:00:00Z 2026-08-03T09:14:30Z)" "rounds down to whole minutes"
assert_eq "0m"  "$(elapsed_minutes 2026-08-03T09:00:00Z 2026-08-03T09:00:20Z)" "handles sub-minute runs"
assert_eq "95m" "$(elapsed_minutes 2026-08-03T09:00:00Z 2026-08-03T10:35:00Z)" "handles runs over an hour"

# --- cmd_grade fixtures ------------------------------------------------------
#
# ROOT comes from BASH_SOURCE, so a copy of bin/evalcode inside a temp dir
# treats that dir as the project root. Stub `mix` and `elixir` binaries earlier
# on PATH decide what each case's version check, test run and compile do.

# new_fixture <task-id> <mix-test-exit> <mix-compile-exit> <compile-output> \
#             [tests-run] [min-tests] [requires-clean-compile]
new_fixture() {
  local task="$1" test_exit="$2" compile_exit="$3" compile_out="$4"
  local tests_run="${5:-32}" min_tests="${6:-32}" clean_compile="${7:-}"
  local fx

  if [ -z "$clean_compile" ]; then
    case "$task" in
      02-type-clean) clean_compile=yes ;;
      *) clean_compile=no ;;
    esac
  fi

  fx="$(mktemp -d "$FIXTURE_ROOT/fx.XXXXXX")"

  mkdir -p "$fx/bin" "$fx/stub" "$fx/tasks/$task/holdout" \
           "$fx/runs/r1/test" "$fx/runs/r1/lib" "$fx/runs/r1.base/lib"

  cp "$ROOT/bin/evalcode" "$fx/bin/evalcode"
  chmod +x "$fx/bin/evalcode"

  printf 'defmodule HoldoutTest do\nend\n' > "$fx/tasks/$task/holdout/holdout_test.exs"
  printf 'defmodule A do\n  def a, do: :ok\nend\n' > "$fx/runs/r1/lib/a.ex"
  cp "$fx/runs/r1/lib/a.ex" "$fx/runs/r1.base/lib/a.ex"

  printf 'min_tests=%s\nrequires_clean_compile=%s\n' "$min_tests" "$clean_compile" \
    > "$fx/tasks/$task/grading.conf"

  printf '# Results\n\n| task | model | harness | completed | duration | cost | compile | notes |\n|---|---|---|---|---|---|---|---|\n' \
    > "$fx/RESULTS.md"

  printf 'task=%s\nmodel=testmodel\nharness=testharness\nstarted=2026-08-03T09:00:00Z\n' \
    "$task" > "$fx/runs/r1.meta"

  cat > "$fx/stub/mix" <<STUB
#!/usr/bin/env bash
case "\$1" in
  test)    printf 'Result: %s passed\n' "$tests_run"; exit $test_exit ;;
  compile) printf '%s\n' "$compile_out";              exit $compile_exit ;;
  *)       exit 0 ;;
esac
STUB
  chmod +x "$fx/stub/mix"

  cat > "$fx/stub/elixir" <<'STUB'
#!/usr/bin/env bash
printf 'Erlang/OTP 27 [erts-15.2.7.9] [source] [64-bit]\n\nElixir 1.20.2 (compiled with Erlang/OTP 27)\n'
STUB
  chmod +x "$fx/stub/elixir"

  echo "$fx"
}

# grade_fixture <fixture-dir> [extra args...] -> prints the emitted row
grade_fixture() {
  local fx="$1"; shift
  PATH="$fx/stub:$PATH" "$fx/bin/evalcode" grade r1 "$@" 2>/dev/null
}

# grade_fixture_status <fixture-dir> [extra args...] -> prints the exit code
grade_fixture_status() {
  local fx="$1"; shift
  PATH="$fx/stub:$PATH" "$fx/bin/evalcode" grade r1 "$@" >/dev/null 2>&1
  echo $?
}

# cell <field-number> — pulls one column out of a rendered row
cell() { awk -F'|' -v n="$1" '{print $n}' | sed 's/^ *//;s/ *$//'; }

echo "cmd_grade — outcomes"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
assert_eq "| 01-live-orders | testmodel | testharness | yes | 0m | \$1.23 | clean |  |" \
  "$(grade_fixture "$fx" --cost 1.23 --duration 0m)" "passing run is completed"

fx="$(new_fixture 01-live-orders 1 0 "Compiling 1 file (.ex)")"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" "failing tests are not completed"

fx="$(new_fixture 01-live-orders 0 1 "warning: something")"
assert_eq "yes" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "a task with requires_clean_compile=no ignores compile warnings"

fx="$(new_fixture 02-type-clean 0 1 "warning: something" 41 41)"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "a task with requires_clean_compile=yes needs a clean compile"

# The compile gate used to be keyed on the literal task id `02-type-clean`, so
# a new task silently got no gate at all. It comes from grading.conf now.
fx="$(new_fixture 03-future-task 0 1 "warning: something" 32 32 yes)"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "the compile gate is not keyed on the task id"

echo "cmd_grade — test-count floor"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)" 10 32)"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "fewer tests than the floor is not completed"
assert_eq "only 10 of 32 tests ran" "$(grade_fixture "$fx" --duration 0m --regrade | cell 9)" \
  "and the row says how many ran"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)" 0 32)"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "excluding every test is not completed"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
cat > "$fx/stub/mix" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  test)    printf 'There are no tests to run\n'; exit 0 ;;
  compile) printf 'Compiling 1 file (.ex)\n';    exit 0 ;;
  *)       exit 0 ;;
esac
STUB
chmod +x "$fx/stub/mix"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "an unreadable test count is not completed"
assert_eq "test count unreadable" "$(grade_fixture "$fx" --duration 0m --regrade | cell 9)" \
  "and says so in notes"

# A suite that fails to compile prints no summary line either. That is a plain
# test failure, not the suspicious case, and should read as one.
fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
cat > "$fx/stub/mix" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  test)    printf '** (CompileError) test/a_test.exs:1: boom\n'; exit 1 ;;
  compile) printf 'Compiling 1 file (.ex)\n';                    exit 0 ;;
  *)       exit 0 ;;
esac
STUB
chmod +x "$fx/stub/mix"
assert_eq "tests failed" "$(grade_fixture "$fx" --duration 0m | cell 9)" \
  "a suite that never ran reads as a test failure, not an unreadable count"

echo "cmd_grade — grading.conf"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
rm -f "$fx/tasks/01-live-orders/grading.conf"
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m)" "a missing grading.conf fails loudly"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
printf 'min_tests=lots\nrequires_clean_compile=no\n' > "$fx/tasks/01-live-orders/grading.conf"
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m)" "a non-numeric min_tests fails loudly"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
printf 'min_tests=32\nrequires_clean_compile=maybe\n' > "$fx/tasks/01-live-orders/grading.conf"
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m)" \
  "a nonsense requires_clean_compile fails loudly"

echo "cmd_grade — compile column"

fx="$(new_fixture 01-live-orders 0 1 "warning: unused variable
warning: another one")"
assert_eq "2 warnings" "$(grade_fixture "$fx" --duration 0m | cell 8)" "counts warnings"

fx="$(new_fixture 01-live-orders 0 1 "** (CompileError) lib/a.ex:1: boom")"
assert_eq "error" "$(grade_fixture "$fx" --duration 0m | cell 8)" \
  "a hard failure is an error, not 0 warnings"

fx="$(new_fixture 01-live-orders 0 1 "warning: no route path for Router matches \"/nope\"")"
assert_eq "1 warnings (routes)" "$(grade_fixture "$fx" --duration 0m | cell 8)" \
  "flags route warnings as a distinct cause"

echo "cmd_grade — suppression scan"

fx="$(new_fixture 02-type-clean 0 0 "Compiling 1 file (.ex)" 41 41)"
printf 'defmodule A do\n  @compile {:no_warn_undefined, Foo}\n  def a, do: :ok\nend\n' > "$fx/runs/r1/lib/a.ex"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "suppression in an edited file is caught"
assert_eq "suppressions added" "$(grade_fixture "$fx" --duration 0m --regrade | cell 9)" \
  "and the reason reaches the results table, not just stderr"

fx="$(new_fixture 02-type-clean 0 0 "Compiling 1 file (.ex)" 41 41)"
printf 'defmodule B do\n  @dialyzer {:nowarn_function, b: 0}\n  def b, do: :ok\nend\n' > "$fx/runs/r1/lib/b.ex"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | cell 5)" \
  "suppression in a new file is caught"

fx="$(new_fixture 02-type-clean 0 0 "Compiling 1 file (.ex)" 41 41)"
grade_fixture "$fx" --duration 0m >/dev/null
assert_eq "0" "$(grep -c 'holdout_test' "$fx/runs/r1.diff.log")" \
  "the diff excludes the grader's own held-out files"

echo "cmd_grade — notes column"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
assert_eq "" "$(grade_fixture "$fx" --duration 0m | cell 9)" "a pass leaves notes empty"

fx="$(new_fixture 01-live-orders 1 0 "Compiling 1 file (.ex)")"
assert_eq "tests failed" "$(grade_fixture "$fx" --duration 0m | cell 9)" "a failing suite says so"

fx="$(new_fixture 02-type-clean 0 1 "warning: something" 41 41)"
assert_eq "compile failed" "$(grade_fixture "$fx" --duration 0m | cell 9)" "a dirty compile says so"

echo "cmd_grade — idempotence"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
grade_fixture "$fx" --duration 0m >/dev/null
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m)" "a second grade is refused"
assert_eq "5" "$(wc -l < "$fx/RESULTS.md" | tr -d ' ')" "and appends no second row"
assert_eq "0" "$(grade_fixture_status "$fx" --duration 0m --regrade)" "--regrade grades it again"
assert_eq "6" "$(wc -l < "$fx/RESULTS.md" | tr -d ' ')" "and that one does append"

# A regrade must not read the held-out tests the previous grade copied in as
# something the model wrote — a held-out file carrying @compile would
# otherwise be scored against the model.
fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
printf 'defmodule HoldoutTest do\n  @compile {:no_warn_undefined, Foo}\nend\n' \
  > "$fx/tasks/01-live-orders/holdout/holdout_test.exs"
grade_fixture "$fx" --duration 0m >/dev/null
assert_eq "yes" "$(grade_fixture "$fx" --duration 0m --regrade | cell 5)" \
  "a regrade does not attribute held-out files to the model"

echo "cmd_grade — malformed input"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
printf 'task=01-live-orders\nmodel=m\nharness=h\nstarted=\n' > "$fx/runs/r1.meta"
assert_eq "1" "$(grade_fixture_status "$fx")" "an empty started fails loudly"
assert_eq "4" "$(wc -l < "$fx/RESULTS.md" | tr -d ' ')" "and appends no row"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
printf 'task=01-live-orders\nmodel=m\nharness=h\nstarted=not-a-date\n' > "$fx/runs/r1.meta"
assert_eq "1" "$(grade_fixture_status "$fx")" "an unparseable started fails loudly"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
rm -rf "$fx/runs/r1.base"
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m)" "a missing base snapshot fails loudly"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
assert_eq "1" "$(grade_fixture_status "$fx" --duration not-a-duration)" \
  "a malformed --duration fails loudly"
assert_eq "4" "$(wc -l < "$fx/RESULTS.md" | tr -d ' ')" "and appends no row"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m --cost 'a lot')" \
  "a malformed --cost fails loudly"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
cat > "$fx/stub/elixir" <<'STUB'
#!/usr/bin/env bash
printf 'Erlang/OTP 28 [erts-16.4.0.3] [source] [64-bit]\n\nElixir 1.18.4 (compiled with Erlang/OTP 28)\n'
STUB
chmod +x "$fx/stub/elixir"
assert_eq "1" "$(grade_fixture_status "$fx" --duration 0m)" "grading under Elixir 1.18 is refused"
assert_eq "4" "$(wc -l < "$fx/RESULTS.md" | tr -d ' ')" "and appends no row"

exit "$FAILED"
