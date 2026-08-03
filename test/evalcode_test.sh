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

echo "run_id_for"
assert_eq "2026-08-03-opus5-01" "$(run_id_for 2026-08-03 opus5 01-live-orders)" "strips the task slug"
assert_eq "2026-08-03-opus5-02" "$(run_id_for 2026-08-03 opus5 02-type-clean)" "handles the second task"

echo "evalcode_status"
assert_eq "yes" "$(evalcode_status 01-live-orders pass clean no)" "01 passes on tests alone"
assert_eq "yes" "$(evalcode_status 01-live-orders pass "2 warnings" no)" "01 ignores compile warnings"
assert_eq "no"  "$(evalcode_status 01-live-orders fail clean no)" "01 fails on failing tests"
assert_eq "no"  "$(evalcode_status 01-live-orders pass clean yes)" "01 fails when suppressions were added"
assert_eq "yes" "$(evalcode_status 02-type-clean pass clean no)" "02 passes on tests plus clean compile"
assert_eq "no"  "$(evalcode_status 02-type-clean pass "1 warnings" no)" "02 fails on any warning"
assert_eq "no"  "$(evalcode_status 02-type-clean fail clean no)" "02 fails on failing tests"
assert_eq "no"  "$(evalcode_status 02-type-clean pass clean yes)" "02 fails when suppressions were added"

echo "format_row"
assert_eq "| 01-live-orders | opus5 | claude-code | yes | 14m | \$2.10 | clean |" \
  "$(format_row 01-live-orders opus5 claude-code yes 14m 2.10 clean)" "renders a full row"
assert_eq "| 01-live-orders | opus5 | claude-code | no | 9m | — | clean |" \
  "$(format_row 01-live-orders opus5 claude-code no 9m "" clean)" "renders an em dash for missing cost"

echo "elapsed_minutes"
assert_eq "14m" "$(elapsed_minutes 2026-08-03T09:00:00Z 2026-08-03T09:14:30Z)" "rounds down to whole minutes"
assert_eq "0m"  "$(elapsed_minutes 2026-08-03T09:00:00Z 2026-08-03T09:00:20Z)" "handles sub-minute runs"
assert_eq "95m" "$(elapsed_minutes 2026-08-03T09:00:00Z 2026-08-03T10:35:00Z)" "handles runs over an hour"

# --- cmd_grade fixtures ------------------------------------------------------
#
# ROOT comes from BASH_SOURCE, so a copy of bin/evalcode inside a temp dir
# treats that dir as the project root. A stub `mix` earlier on PATH decides
# what each case's test run and compile do.

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

# new_fixture <task-id> <mix-test-exit> <mix-compile-exit> <compile-output>
new_fixture() {
  local task="$1" test_exit="$2" compile_exit="$3" compile_out="$4"
  local fx
  fx="$(mktemp -d "$FIXTURE_ROOT/fx.XXXXXX")"

  mkdir -p "$fx/bin" "$fx/stub" "$fx/tasks/$task/holdout" \
           "$fx/runs/r1/test" "$fx/runs/r1/lib" "$fx/runs/r1.base/lib"

  cp "$ROOT/bin/evalcode" "$fx/bin/evalcode"
  chmod +x "$fx/bin/evalcode"

  printf 'defmodule HoldoutTest do\nend\n' > "$fx/tasks/$task/holdout/holdout_test.exs"
  printf 'defmodule A do\n  def a, do: :ok\nend\n' > "$fx/runs/r1/lib/a.ex"
  cp "$fx/runs/r1/lib/a.ex" "$fx/runs/r1.base/lib/a.ex"

  printf '# Results\n\n| task | model | harness | completed | duration | cost | compile |\n|---|---|---|---|---|---|---|\n' \
    > "$fx/RESULTS.md"

  printf 'task=%s\nmodel=testmodel\nharness=testharness\nstarted=2026-08-03T09:00:00Z\n' \
    "$task" > "$fx/runs/r1.meta"

  cat > "$fx/stub/mix" <<STUB
#!/usr/bin/env bash
case "\$1" in
  test)    printf '%s\n' "stub test output"; exit $test_exit ;;
  compile) printf '%s\n' "$compile_out";     exit $compile_exit ;;
  *)       exit 0 ;;
esac
STUB
  chmod +x "$fx/stub/mix"

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

echo "cmd_grade — outcomes"

fx="$(new_fixture 01-live-orders 0 0 "Compiling 1 file (.ex)")"
assert_eq "| 01-live-orders | testmodel | testharness | yes | 0m | \$1.23 | clean |" \
  "$(grade_fixture "$fx" --cost 1.23 --duration 0m)" "passing run is completed"

fx="$(new_fixture 01-live-orders 1 0 "Compiling 1 file (.ex)")"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $5}' | tr -d ' ')" \
  "failing tests are not completed"

fx="$(new_fixture 01-live-orders 0 1 "warning: something")"
assert_eq "yes" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $5}' | tr -d ' ')" \
  "01 ignores compile warnings"

fx="$(new_fixture 02-type-clean 0 1 "warning: something")"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $5}' | tr -d ' ')" \
  "02 requires a clean compile"

echo "cmd_grade — compile column"

fx="$(new_fixture 01-live-orders 0 1 "warning: unused variable
warning: another one")"
assert_eq "2 warnings" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $8}' | sed 's/^ *//;s/ *$//')" \
  "counts warnings"

fx="$(new_fixture 01-live-orders 0 1 "** (CompileError) lib/a.ex:1: boom")"
assert_eq "error" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $8}' | sed 's/^ *//;s/ *$//')" \
  "a hard failure is an error, not 0 warnings"

fx="$(new_fixture 01-live-orders 0 1 "warning: no route path for Router matches \"/nope\"")"
assert_eq "1 warnings (routes)" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $8}' | sed 's/^ *//;s/ *$//')" \
  "flags route warnings as a distinct cause"

echo "cmd_grade — suppression scan"

fx="$(new_fixture 02-type-clean 0 0 "Compiling 1 file (.ex)")"
printf 'defmodule A do\n  @compile {:no_warn_undefined, Foo}\n  def a, do: :ok\nend\n' > "$fx/runs/r1/lib/a.ex"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $5}' | tr -d ' ')" \
  "suppression in an edited file is caught"

fx="$(new_fixture 02-type-clean 0 0 "Compiling 1 file (.ex)")"
printf 'defmodule B do\n  @dialyzer {:nowarn_function, b: 0}\n  def b, do: :ok\nend\n' > "$fx/runs/r1/lib/b.ex"
assert_eq "no" "$(grade_fixture "$fx" --duration 0m | awk -F'|' '{print $5}' | tr -d ' ')" \
  "suppression in a new file is caught"

fx="$(new_fixture 02-type-clean 0 0 "Compiling 1 file (.ex)")"
grade_fixture "$fx" --duration 0m >/dev/null
assert_eq "0" "$(grep -c 'holdout_test' "$fx/runs/r1.diff.log")" \
  "the diff excludes the grader's own held-out files"

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

exit "$FAILED"
