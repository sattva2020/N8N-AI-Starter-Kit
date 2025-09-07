"""
Watch n8n docker logs and run ETL wrapper when migrations complete / service is ready.

Usage: run from repo root. The script assumes a venv at repo_root/.venv and
that `docker` is available on PATH.

It looks for a few readiness indicators in n8n logs (adjustable):
 - 'Editor is now accessible'
 - 'All migrations finished'
 - 'Started server' / 'Listening on'

When one of them appears the script executes the run_with_env.py wrapper with
the venv Python, streams its output, and exits with the wrapper's exit code.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Pattern

RETRY_DELAY = 1.0
# Patterns that indicate n8n finished migrations / is ready for API calls
READY_PATTERNS: list[Pattern] = [
    re.compile(r"Editor is now accessible", re.IGNORECASE),
    re.compile(r"All migrations finished", re.IGNORECASE),
    re.compile(r"Started .*server", re.IGNORECASE),
    re.compile(r"Listening on", re.IGNORECASE),
]


def find_venv_python(repo_root: Path) -> Path:
    if sys.platform.startswith("win"):
        return repo_root / ".venv" / "Scripts" / "python.exe"
    return repo_root / ".venv" / "bin" / "python"


def tail_docker_logs(container: str):
    # Use docker logs -f to stream logs
    cmd = ["docker", "logs", "-f", container]
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def matches_ready(line: str) -> bool:
    for p in READY_PATTERNS:
        if p.search(line):
            return True
    return False


def run_wrapper(repo_root: Path, venv_python: Path) -> int:
    wrapper = repo_root / "services" / "etl-processor" / "run_with_env.py"
    if not wrapper.exists():
        print("run_with_env.py not found at", wrapper, file=sys.stderr)
        return 2
    exe = str(venv_python) if venv_python.exists() else sys.executable
    print(f"Running ETL wrapper with: {exe} {wrapper}")
    return subprocess.call([exe, str(wrapper)])


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    container = os.environ.get("N8N_CONTAINER", "n8n")

    venv_python = find_venv_python(repo_root)
    print("Repo root:", repo_root)
    print("Using venv python:", venv_python)
    print(f"Tailing Docker logs from container '{container}' (Ctrl-C to cancel)")

    proc = tail_docker_logs(container)
    assert proc.stdout is not None

    try:
        for raw in proc.stdout:
            line = raw.rstrip("\n")
            print(line)
            if matches_ready(line):
                print("Readiness indicator found in n8n logs. Starting ETL wrapper...")
                # give n8n a moment to finish boot tasks
                time.sleep(1.0)
                rc = run_wrapper(repo_root, venv_python)
                print(f"ETL wrapper exited with code {rc}")
                return rc
        # if stdout closes, wait a bit and exit
        proc.wait(timeout=1)
        return proc.returncode or 0
    except KeyboardInterrupt:
        print("Interrupted by user")
        proc.terminate()
        return 130
    finally:
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    raise SystemExit(main())
