#!/usr/bin/env bash
# Wrap a command so its outcome is reported to Prometheus.
#
#   run-cron.sh <job_name> -- <command> [args...]
#
# It times the command, captures its exit code, and on failure extracts the last
# non-empty line of stderr as the `reason`, then pushes the metrics. stderr is
# still replayed so whatever consumes cron output (mail, a log) is unchanged.
set -uo pipefail

if [ "$#" -lt 3 ] || [ "$2" != "--" ]; then
    echo "usage: $0 <job_name> -- <command> [args...]" >&2
    exit 2
fi

job="$1"
shift 2

here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=push_cron_metric.sh
. "${here}/push_cron_metric.sh"

log="$(mktemp)"
trap 'rm -f "${log}"' EXIT

start="$(date +%s)"
"$@" 2>"${log}"
exit_code=$?
duration=$(( $(date +%s) - start ))

cat "${log}" >&2   # replay stderr unchanged

reason=""
if [ "${exit_code}" -ne 0 ]; then
    reason="$(grep -v '^[[:space:]]*$' "${log}" | tail -n 1)"
    [ -z "${reason}" ] && reason="exit ${exit_code} with no stderr output"
fi

push_cron_metric "${job}" "${exit_code}" "${duration}" "${reason}"
exit "${exit_code}"
