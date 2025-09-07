#!/usr/bin/env bash
set -euo pipefail

# remote-run-start.sh
# Helper to run ./start.sh on a remote server non-interactively and collect
# logs and diagnostics into a single folder you can download and share.

TIMESTAMP=$(date -u +%Y%m%d_%H%M%SZ)
OUTDIR=".internal/remote-run-${TIMESTAMP}"
mkdir -p "$OUTDIR"
LOG="$OUTDIR/start-run.log"

echo "Remote run started: $(date -u)" | tee "$LOG"
echo "Host: $(hostname -f 2>/dev/null || hostname)" | tee -a "$LOG"
echo "CWD: $(pwd)" | tee -a "$LOG"

echo "--- Git info ---" | tee -a "$LOG"
git rev-parse --abbrev-ref HEAD 2>/dev/null | tee -a "$LOG" || true
git rev-parse --short HEAD 2>/dev/null | tee -a "$LOG" || true

echo "--- System info ---" | tee -a "$LOG"
uname -a | tee -a "$LOG"
echo "$(date -u)" | tee -a "$LOG"

echo "--- Docker info ---" | tee -a "$LOG"
docker --version 2>&1 | tee -a "$LOG" || true
docker info 2>&1 | sed -n '1,120p' | tee -a "$LOG" || true
docker compose version 2>&1 | tee -a "$LOG" || true

echo "--- GPU detection ---" | tee -a "$LOG"
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi available:" | tee -a "$LOG"
  nvidia-smi -L 2>&1 | tee -a "$LOG" || true
else
  echo "nvidia-smi: not found" | tee -a "$LOG"
fi

if command -v rocminfo >/dev/null 2>&1; then
  echo "rocminfo available:" | tee -a "$LOG"
  rocminfo 2>&1 | sed -n '1,120p' | tee -a "$LOG" || true
else
  echo "rocminfo: not found" | tee -a "$LOG"
fi

echo "--- PCI devices (grep GPU) ---" | tee -a "$LOG"
lspci 2>/dev/null | egrep -i 'vga|3d|display|nvidia|amd' | tee -a "$LOG" || true

# Ensure compose contexts resolve correctly on remote
if [[ -z "${COMPOSE_PROJECT_DIR:-}" ]]; then
  export COMPOSE_PROJECT_DIR="$(pwd)"
  echo "Exported COMPOSE_PROJECT_DIR=$COMPOSE_PROJECT_DIR" | tee -a "$LOG"
else
  echo "COMPOSE_PROJECT_DIR already set: $COMPOSE_PROJECT_DIR" | tee -a "$LOG"
fi

# Make start non-interactive where possible. Many helper scripts respect AUTO_YES
export AUTO_YES=1

echo "--- Running ./start.sh (no args) ---" | tee -a "$LOG"
echo "Command: ./start.sh" | tee -a "$LOG"

# Run start.sh and stream+save output. Use timeout as a precaution (adjustable).
if [[ -x ./start.sh ]]; then
  # Prefer to keep the output live and saved for convenience
  bash -c "./start.sh" 2>&1 | tee -a "$LOG"
  START_RC=${PIPESTATUS[0]:-0}
  echo "start.sh exit code: $START_RC" | tee -a "$LOG"
else
  echo "ERROR: ./start.sh not found or not executable" | tee -a "$LOG"
  exit 2
fi

echo "--- Collecting docker-compose merged config ---" | tee -a "$LOG"
docker compose config > "$OUTDIR/compose-merged.yml" 2>>"$LOG" || true

echo "--- docker compose ps ---" | tee -a "$LOG"
docker compose ps --all 2>&1 | tee -a "$LOG" || true

echo "--- docker images (top 100) ---" | tee -a "$LOG"
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}' | head -n 100 | tee -a "$LOG" || true

echo "--- Gathering docker logs for started services (last 5m) ---" | tee -a "$LOG"
mkdir -p "$OUTDIR/logs"
# Save logs for relevant profiles (gpu, developer-gpu)
services=$(docker compose ps --services 2>/dev/null || true)
for svc in $services; do
  echo "Collecting logs for $svc" | tee -a "$LOG"
  docker compose logs --no-color --since 5m "$svc" > "$OUTDIR/logs/${svc}.log" 2>>"$LOG" || true
done

echo "--- Archiving results ---" | tee -a "$LOG"
tar -czf "$OUTDIR.tar.gz" -C ".internal" "remote-run-${TIMESTAMP}" 2>>"$LOG" || true

echo "Remote run finished: $(date -u)" | tee -a "$LOG"
echo "Artifacts saved to: $OUTDIR and $OUTDIR.tar.gz" | tee -a "$LOG"

echo
echo "To download the archive, use scp or your preferred transfer tool. Example:" | tee -a "$LOG"
echo "scp user@server:$(pwd)/$OUTDIR.tar.gz ./" | tee -a "$LOG"

exit 0
