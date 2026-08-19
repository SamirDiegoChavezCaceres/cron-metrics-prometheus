#!/usr/bin/env bash
# Pure-bash tests for _sanitize_reason (no bats dependency).
#   bash tests/test_sanitize.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/push_cron_metric.sh
. "${here}/../scripts/push_cron_metric.sh"

fail=0
check() {
    local name="$1" got="$2" want="$3"
    if [ "${got}" = "${want}" ]; then
        echo "ok   - ${name}"
    else
        echo "FAIL - ${name}"
        echo "       got:  [${got}]"
        echo "       want: [${want}]"
        fail=1
    fi
}

check "collapses newlines"  "$(_sanitize_reason $'line1\nline2')"  "line1 line2"
check "escapes quotes"      "$(_sanitize_reason 'he said "hi"')"   'he said \"hi\"'
check "escapes backslash"   "$(_sanitize_reason 'a\b')"            'a\\b'

long="$(printf 'x%.0s' {1..300})"
truncated="$(_sanitize_reason "${long}")"
check "input is 300 chars"  "${#long}"       "300"   # sanity
check "truncated to 200"    "${#truncated}"  "200"

exit "${fail}"
