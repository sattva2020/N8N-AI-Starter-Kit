#!/usr/bin/env bash
# Run repository checks and ETL on a remote server
# Usage: ./scripts/run_remote_tests.sh [path-to-repo]
# If no path provided, assumes current directory is repository root.
set -euo pipefail
REPO_DIR=${1:-$(pwd)}
cd "$REPO_DIR"
PYTHON=${PYTHON:-python3}
VENV_DIR=.venv
LOG_DIR=logs
mkdir -p "$LOG_DIR"

echo "[run_remote_tests] repo: $REPO_DIR"
# Create venv if missing
if [ ! -d "$VENV_DIR" ]; then
  echo "Creating virtualenv in $VENV_DIR"
  $PYTHON -m venv "$VENV_DIR"
fi

# Activate venv
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

# Upgrade pip and install tooling
python -m pip install --upgrade pip wheel setuptools
pip install ruff pytest mypy

# Install service dependencies as needed (adjust if you want full install)
# Prefer per-service requirements to keep installs minimal
if [ -f services/etl-processor/requirements.txt ]; then
  echo "Installing ETL service requirements (may take a while)"
  pip install -r services/etl-processor/requirements.txt
fi

# Run linter
echo "Running ruff check ."
ruff check . | tee "$LOG_DIR/ruff.log" || true

# Run tests
echo "Running pytest"
pytest -q | tee "$LOG_DIR/pytest.log"

# Run mypy for selected folders (may need installed stubs)
echo "Running mypy (services, scripts)"
python -m mypy --config-file ./mypy.ini services scripts 2>&1 | tee "$LOG_DIR/mypy.log" || true

# Prepare minimal ETL env if services/etl-processor/.env.etl exists
ETL_ENV_FILE=services/etl-processor/.env.etl
if [ -f "$ETL_ENV_FILE" ]; then
  echo "Found $ETL_ENV_FILE, copying to repo root as .env for ETL run"
  cp "$ETL_ENV_FILE" .env
  CLEANUP_ENV=true
else
  CLEANUP_ENV=false
fi

# Run ETL (foreground) and capture output
echo "Starting ETL process (foreground). Logs -> $LOG_DIR/etl.log"
# Run with venv python
python services/etl-processor/main.py 2>&1 | tee "$LOG_DIR/etl.log" || true

# Restore environment file if we created it
if [ "$CLEANUP_ENV" = true ]; then
  rm -f .env
fi

echo "Done. Logs available in $LOG_DIR"
