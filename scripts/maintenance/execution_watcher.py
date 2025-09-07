#!/usr/bin/env python3
"""execution_watcher.py
Polls n8n executions and reports failed ones; optional remediation via re-run.

Usage:
  python scripts/maintenance/execution_watcher.py --token TOKEN --n8n http://localhost:5678 --since 60

"""

import argparse
import time
from datetime import datetime, timedelta

import requests


def list_failed_executions(base_url, token, _since_minutes=60):
    url = f"{base_url.rstrip('/')}/rest/executions"
    params = {"filter": "failed", "limit": 100}
    # optional: filter by updatedAfter or createdAt if API supports
    r = requests.get(url, headers={"Authorization": f"Bearer {token}"}, params=params, timeout=10)
    r.raise_for_status()
    return r.json()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--token", required=True)
    p.add_argument("--n8n", default="http://localhost:5678")
    p.add_argument("--since", type=int, default=60, help="minutes to look back")
    p.add_argument("--poll-interval", type=int, default=300, help="seconds between polls")
    p.add_argument("--alert-cmd", default=None, help="command to run on alert (e.g., curl to webhook)")
    args = p.parse_args()

    lookback = datetime.utcnow() - timedelta(minutes=args.since)
    print(f"Starting execution watcher (since {lookback.isoformat()}), polling every {args.poll_interval}s")
    while True:
        try:
            results = list_failed_executions(args.n8n, args.token, args.since)
            count = len(results.get('data', results) if isinstance(results, dict) else results)
            if count:
                print(f"Found {count} failed executions: ")
                # print short summary for each
                items = results.get('data', results) if isinstance(results, dict) else results
                for ex in items:
                    ex_id = ex.get('id')
                    workflow_id = ex.get('workflowId') or ex.get('workflow', {}).get('id')
                    status = ex.get('status')
                    started_at = ex.get('startedAt')
                    print(f" - execution id={ex_id} workflow={workflow_id} status={status} startedAt={started_at}")
                if args.alert_cmd:
                    import subprocess

                    try:
                        subprocess.run(args.alert_cmd, shell=True, check=False)
                    except Exception as e:
                        print(f"Alert command failed: {e}")
            else:
                print(f"No failed executions at {datetime.utcnow().isoformat()}")
        except Exception as e:
            print(f"Watcher error: {e}")
        time.sleep(args.poll_interval)


if __name__ == '__main__':
    main()
