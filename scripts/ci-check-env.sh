#!/usr/bin/env bash
set -euo pipefail

# CI helper to validate env.schema and detect placeholder values in .env or template.env
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT_DIR"

echo "Checking env.schema presence..."
if [ ! -f env.schema ]; then
  echo "env.schema not found. Please add env.schema to the repository." >&2
  exit 1
fi

echo "Running placeholder scan against .env and template.env (if present)..."
FILES_TO_CHECK=()
if [ -f .env ]; then FILES_TO_CHECK+=(.env); fi
if [ -f template.env ]; then FILES_TO_CHECK+=(template.env); fi

if [ ${#FILES_TO_CHECK[@]} -eq 0 ]; then
  echo "No .env/template.env present in repo root - skipping placeholder checks."
  exit 0
fi

for f in "${FILES_TO_CHECK[@]}"; do
  echo "Scanning $f for placeholders..."
  if scripts/check-env-placeholders.sh "$f"; then
    echo "  $f: OK"
  else
    echo "  $f: found placeholders or empty values. Fix before merging." >&2
    exit 1
  fi
done

echo "Env validation passed."
