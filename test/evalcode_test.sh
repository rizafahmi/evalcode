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

exit "$FAILED"
