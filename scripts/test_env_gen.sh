#!/bin/bash
# Simple smoke test: run setup.sh --generate-only in a temp dir and verify .env contains NEO4J_PASSWORD
set -euo pipefail
WORKDIR=$(mktemp -d)
echo "Using temp dir: $WORKDIR"
cp -r . "$WORKDIR/project"
cd "$WORKDIR/project"
chmod +x ./scripts/setup.sh
echo "Running setup.sh --generate-only..."
./scripts/setup.sh --generate-only
if [ ! -f .env ]; then
  echo "FAIL: .env not created"
  exit 2
fi
val=$(grep -E '^NEO4J_PASSWORD=' .env | tail -n1 | cut -d'=' -f2- || true)
if [ -z "$val" ]; then
  echo "FAIL: NEO4J_PASSWORD missing in .env"
  exit 3
fi
len=${#val}
if [ $len -lt 8 ]; then
  echo "FAIL: NEO4J_PASSWORD too short (len=$len)"
  exit 4
fi
echo "PASS: NEO4J_PASSWORD present (len=$len)"
exit 0
