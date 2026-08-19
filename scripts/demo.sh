#!/usr/bin/env bash
# A no-Docker walkthrough: the wrapper captures a failing job's real error,
# and the reason is sanitized for the Prometheus exposition format.
#
#   bash scripts/demo.sh
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

echo "=== 1. A cron job fails; run-cron captures the real error ==="
PUSHGATEWAY_URL=http://localhost:1 bash "$here/run-cron.sh" demo_job -- bash "$here/../examples/demo-job.sh"
echo "   -> exit 1 captured; the last stderr line becomes the alert 'reason'"
echo "   (no gateway here, so the push is swallowed; see README for the live stack)"
echo
echo "=== 2. The reason is sanitized for the Prometheus text format ==="
bash "$here/../tests/test_sanitize.sh"
