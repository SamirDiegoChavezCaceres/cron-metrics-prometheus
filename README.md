# cron-metrics-prometheus

Turn any cron job into a monitored one, and make the alert tell you **why** it
failed, not just that it did.

A wrapper runs your job, captures its exit code, duration, and - on failure -
the last line of stderr, then pushes those to a Prometheus Pushgateway. The
alert rule carries that error line as a label, so the page says
`backup failed — ERROR: disk full` instead of `exit=1`.

Everything here is a from-scratch, vendor-neutral rewrite of a pattern I shipped
in production.

## The problem it solves

The usual cron-to-Prometheus setup pushes `last_exit`, you alert on
`last_exit != 0`, and the alert says a job failed. Then you SSH into the box at
an awkward hour and grep logs to find out what actually broke. The fix is cheap:
capture the error at the moment of failure and carry it into the alert.

## Use it

```bash
# <job_name> -- <command...>
./scripts/run-cron.sh nightly_backup -- /usr/local/bin/backup.sh
```

In a crontab:

```cron
PUSHGATEWAY_URL=http://localhost:9091
0 3 * * *  /opt/cron-metrics/scripts/run-cron.sh nightly_backup -- /usr/local/bin/backup.sh
```

The wrapper replays stderr unchanged, so anything already consuming cron output
(mail, a log file) keeps working.

## Metrics pushed

| Metric | Meaning |
|--------|---------|
| `cron_sh_last_exit{job,reason}` | 0 = success, non-zero = failure; `reason` holds the captured error |
| `cron_sh_duration_seconds{job}` | how long the run took |
| `cron_sh_last_run_timestamp_seconds{job}` | when it last ran (powers a staleness alert) |

`reason` is sanitized before it is sent (collapsed to one line, quotes and
backslashes escaped, truncated), because a raw multi-line stderr dump would
otherwise corrupt the Prometheus exposition payload.

## Alerts (`prometheus/alerts.yml`)

- **CronJobFailed** - `cron_sh_last_exit != 0`; the annotation is
  `{{ $labels.job }} failed — {{ $labels.reason }}`.
- **CronJobStale** - a job that stops running never reports a failure, so
  staleness (`time() - last_run > 1h`) gets its own alert.

## Try the whole stack

```bash
docker compose up -d          # pushgateway :9091, prometheus :9090, grafana :3000
PUSHGATEWAY_URL=http://localhost:9091 \
  ./scripts/run-cron.sh demo_job -- ./examples/demo-job.sh    # a job that fails on purpose
curl -s localhost:9091/metrics | grep cron_sh_last_exit
# cron_sh_last_exit{job="demo_job",reason="ERROR: connection to database timed out after 30s"} 1
```

Open Prometheus at http://localhost:9090/alerts to watch `CronJobFailed` fire
with the reason attached. Grafana (http://localhost:3000) comes with the
Prometheus datasource pre-provisioned.

## Tests

```bash
bash tests/test_sanitize.sh
```

Covers the sanitizer: multi-line collapse, quote and backslash escaping, and
truncation - the parts that would otherwise break the metrics payload.

## License

MIT.
