#!/usr/bin/env bash
set -euo pipefail

# This script expects a persistent, host-provided clone mounted at /opt/n8n-workflows.
# It will only run automatically when N8N_AUTO_IMPORT=true. Run manually with --force to override.

# Repository to clone
REPO_URL="https://github.com/Zie619/n8n-workflows.git"
# The importer expects the host to pre-clone workflows into the container at /opt/n8n-workflows
# No runtime cloning is performed inside the image to avoid accidental writes/changes to upstream.
PERSISTENT_DIR="${PERSISTENT_DIR:-/opt/n8n-workflows}"

ALLOW_RUNTIME_CLONE=${ALLOW_RUNTIME_CLONE:-false}
# Audit log for runtime operations (appends)
AUDIT_LOG=${AUDIT_LOG:-/var/log/n8n-importer/audit.log}
# Ensure audit log directory exists if the container has permission (best-effort)
mkdir -p "$(dirname "${AUDIT_LOG}")" 2>/dev/null || true
# If set, skip executing the python import (useful for tests)
SKIP_IMPORT=${SKIP_IMPORT:-false}

# CLI flags: --force to run regardless of N8N_AUTO_IMPORT
if [ "${N8N_AUTO_IMPORT:-false}" != "true" ] && [ "${1:-}" != "--force" ]; then
  echo "N8N_AUTO_IMPORT is not enabled; skipping automatic import."
  echo "To enable automatic runs set N8N_AUTO_IMPORT=true, or run this script manually with --force."
  exit 0
fi

WORK_DIR=""
if [ -d "${PERSISTENT_DIR}/.git" ]; then
  echo "Using existing persistent clone mounted at ${PERSISTENT_DIR}"
  WORK_DIR="${PERSISTENT_DIR}"
else
  echo "Persistent workflows not found at ${PERSISTENT_DIR}."
  if [ "${ALLOW_RUNTIME_CLONE}" = "true" ]; then
    TMP_DIR="/tmp/n8n-workflows"
    echo "ALLOW_RUNTIME_CLONE=true — attempting runtime clone into ${TMP_DIR}"
    rm -rf "${TMP_DIR}"
    # Allow tests to force git-unavailable behaviour without manipulating PATH
    if [ "${TEST_FORCE_NO_GIT:-false}" = "true" ]; then
      echo "WARNING: TEST_FORCE_NO_GIT=true — simulating missing git (test mode)" >&2
      echo "$(date -u --iso-8601=seconds) RUNTIME_CLONE_FAILED git_missing" >> "${AUDIT_LOG}" 2>/dev/null || true
      exit 1
    fi
    if ! command -v git >/dev/null 2>&1; then
      echo "WARNING: ALLOW_RUNTIME_CLONE=true but git not available in image; runtime clone not possible." >&2
      echo "$(date -u --iso-8601=seconds) RUNTIME_CLONE_FAILED git_missing" >> "${AUDIT_LOG}" 2>/dev/null || true
      exit 1
    fi
    if git clone --depth 1 "${REPO_URL}" "${TMP_DIR}"; then
      echo "Runtime clone successful: ${TMP_DIR}"
      echo "$(date -u --iso-8601=seconds) RUNTIME_CLONE_SUCCESS ${TMP_DIR}" >> "${AUDIT_LOG}" 2>/dev/null || true
      WORK_DIR="${TMP_DIR}"
    else
      echo "Runtime clone failed. Exiting." >&2
      echo "$(date -u --iso-8601=seconds) RUNTIME_CLONE_FAILED clone_error" >> "${AUDIT_LOG}" 2>/dev/null || true
      exit 1
    fi
  else
  echo "Please run the host setup script which will clone the repository into ./services/n8n-importer/n8n-workflows and mount it into the container at /opt/n8n-workflows."
  echo "To allow runtime cloning (not recommended for production), set ALLOW_RUNTIME_CLONE=true in the container environment."
    echo "Exiting without performing an import to avoid accidental runtime clones."
    exit 1
  fi
fi

cd "${WORK_DIR}"

if [ -f requirements.txt ]; then
  echo "Installing Python requirements from requirements.txt..."
  python -m pip install --no-cache-dir -r requirements.txt
fi

if [ "${SKIP_IMPORT}" = "true" ]; then
  echo "SKIP_IMPORT=true — skipping actual import (test mode)"
  echo "$(date -u --iso-8601=seconds) IMPORT_SKIPPED ${WORK_DIR}" >> "${AUDIT_LOG}" 2>/dev/null || true
else
  # Prefer a host-supplied, repo-controlled bash importer if present inside the
  # mounted workflows repository. This allows the project to provide a single
  # canonical importer script (for example: scripts/import_workflows_to_n8n.sh)
  # copied or symlinked into the mounted folder under host-scripts/ or project root.
  HOST_SCRIPT1="${WORK_DIR%/}/host-scripts/import_workflows_to_n8n.sh"
  HOST_SCRIPT2="${WORK_DIR%/}/import_workflows_to_n8n.sh"

  if [ -x "${HOST_SCRIPT1}" ]; then
    echo "Found host importer script: ${HOST_SCRIPT1} — executing"
    echo "$(date -u --iso-8601=seconds) IMPORT_START_HOST_SCRIPT ${HOST_SCRIPT1}" >> "${AUDIT_LOG}" 2>/dev/null || true
    # prefer internal service DNS name for n8n when running inside container
    INTERNAL_N8N_URL=${N8N_INTERNAL_URL:-http://n8n:5678}
    # call script with token if available
    if [ -n "${N8N_ADMIN_TOKEN:-}" ]; then
      "${HOST_SCRIPT1}" --dir "${WORK_DIR%/}/n8n/workflows/imported" --token "${N8N_ADMIN_TOKEN}" --n8n-url "${INTERNAL_N8N_URL}"
    else
      "${HOST_SCRIPT1}" --dir "${WORK_DIR%/}/n8n/workflows/imported" --n8n-url "${INTERNAL_N8N_URL}"
    fi
    echo "$(date -u --iso-8601=seconds) IMPORT_FINISHED_HOST_SCRIPT ${HOST_SCRIPT1}" >> "${AUDIT_LOG}" 2>/dev/null || true
  elif [ -x "${HOST_SCRIPT2}" ]; then
    echo "Found host importer script: ${HOST_SCRIPT2} — executing"
    echo "$(date -u --iso-8601=seconds) IMPORT_START_HOST_SCRIPT ${HOST_SCRIPT2}" >> "${AUDIT_LOG}" 2>/dev/null || true
    INTERNAL_N8N_URL=${N8N_INTERNAL_URL:-http://n8n:5678}
    if [ -n "${N8N_ADMIN_TOKEN:-}" ]; then
      "${HOST_SCRIPT2}" --dir "${WORK_DIR%/}/n8n/workflows/imported" --token "${N8N_ADMIN_TOKEN}" --n8n-url "${INTERNAL_N8N_URL}"
    else
      "${HOST_SCRIPT2}" --dir "${WORK_DIR%/}/n8n/workflows/imported" --n8n-url "${INTERNAL_N8N_URL}"
    fi
    echo "$(date -u --iso-8601=seconds) IMPORT_FINISHED_HOST_SCRIPT ${HOST_SCRIPT2}" >> "${AUDIT_LOG}" 2>/dev/null || true
  else
    echo "No host bash importer found — falling back to python importer"
    echo "Running import_workflows.py from ${WORK_DIR}"
    python import_workflows.py
    echo "$(date -u --iso-8601=seconds) IMPORT_FINISHED ${WORK_DIR}" >> "${AUDIT_LOG}" 2>/dev/null || true
  fi
fi

echo "Importer finished"
exit 0
