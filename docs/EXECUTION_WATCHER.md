Execution watcher

`scripts/maintenance/execution_watcher.py` polls the n8n REST API for failed
executions and prints a short report. Optionally you can supply `--alert-cmd`
to call an external webhook or command when failures are detected.

Example:

```bash
python scripts/maintenance/execution_watcher.py --token "$N8N_ADMIN_TOKEN" --n8n http://localhost:5678 --since 30 --poll-interval 120 --alert-cmd "curl -X POST -H 'Content-Type: application/json' -d '{\"text\":\"n8n failures detected\"}' https://hooks.example.com"
```

Notes:

- The script is intentionally simple; in production you may run it under a
  process supervisor (systemd, Docker, k8s CronJob) and integrate with alerting.
