#!/usr/bin/env bash
# A toy "cron job" that fails with a real error message, to show the reason
# flow end to end:
#
#   PUSHGATEWAY_URL=http://localhost:9091 \
#     ./scripts/run-cron.sh demo_job -- ./examples/demo-job.sh
#
# Then query the gateway and you will see the message on the metric's label:
#   curl -s localhost:9091/metrics | grep cron_sh_last_exit
set -euo pipefail

echo "starting work..."
sleep 1
echo "ERROR: connection to database timed out after 30s" >&2
exit 1
