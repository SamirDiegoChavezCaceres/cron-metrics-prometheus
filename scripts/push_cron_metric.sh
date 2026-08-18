#!/usr/bin/env bash
# Source this file to push cron outcome metrics to a Prometheus Pushgateway.
#
#   push_cron_metric <job_name> <exit_code> <duration_seconds> [reason]
#
# It pushes three gauges to ${PUSHGATEWAY_URL:-http://localhost:9091}:
#   cron_sh_last_exit{reason="..."}        0 = success, non-zero = failure
#   cron_sh_duration_seconds               how long the run took
#   cron_sh_last_run_timestamp_seconds     unix time of the last run
#
# The point of this file is the `reason` label. An alert on exit != 0 that only
# says "exit=1" tells you a cron failed but not why; you then go digging through
# logs on a box at an awkward hour. Carrying the last error line as a label puts
# the cause straight in the alert.
#
# curl failures are swallowed so a missing gateway never makes a cron job fail.

# Make an arbitrary error string safe for the Prometheus text exposition format:
# single line, backslashes and quotes escaped, truncated. A raw multi-line
# stderr dump would otherwise corrupt the payload or inject label text.
_sanitize_reason() {
    printf '%s' "$1" \
        | tr '\r\n\t' '   ' \
        | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
        | cut -c1-200
}

push_cron_metric() {
    local job="$1" exit_code="$2" duration="$3" reason="${4:-}"
    local pgw="${PUSHGATEWAY_URL:-http://localhost:9091}"
    reason="$(_sanitize_reason "${reason}")"

    cat <<EOF | curl -sf --max-time 5 --data-binary @- "${pgw}/metrics/job/${job}" >/dev/null 2>&1 || true
# TYPE cron_sh_last_exit gauge
cron_sh_last_exit{reason="${reason}"} ${exit_code}
# TYPE cron_sh_duration_seconds gauge
cron_sh_duration_seconds ${duration}
# TYPE cron_sh_last_run_timestamp_seconds gauge
cron_sh_last_run_timestamp_seconds $(date +%s)
EOF
}
