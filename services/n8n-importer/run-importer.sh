#!/usr/bin/env bash
set -euo pipefail

## Optional automatic importer guarded by N8N_AUTO_IMPORT (default: false)
REPO_URL="https://github.com/Zie619/n8n-workflows.git"
CLONE_DIR="/tmp/n8n-workflows"

if [ "${N8N_AUTO_IMPORT:-false}" != "true" ]; then
  echo "N8N_AUTO_IMPORT is not enabled; skipping automatic n8n-workflows clone and import."
  echo "To enable: set environment variable N8N_AUTO_IMPORT=true"
  exit 0
fi

# Clone the official n8n-workflows repository at runtime to ensure fresh copy
if [ -d "$CLONE_DIR" ]; then
  echo "Removing existing clone..."
  rm -rf "$CLONE_DIR"
fi

echo "Cloning $REPO_URL..."
git clone --depth 1 "$REPO_URL" "$CLONE_DIR"

cd "$CLONE_DIR"

echo "Installing Python dependencies..."
python -m pip install --no-cache-dir -r requirements.txt

# Ensure npx/n8n is available (Node/npm installed in image)
if ! command -v npx >/dev/null 2>&1; then
  echo "npx not available; exiting"
  exit 1
fi

echo "Running importer..."
python import_workflows.py

echo "Importer finished"

# Keep container exit code from python import result
exit 0
