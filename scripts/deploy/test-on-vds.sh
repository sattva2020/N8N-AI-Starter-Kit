#!/usr/bin/env bash
set -euo pipefail
# Simple, idempotent script to perform a full smoke/deploy test of this repository on a fresh VDS.
# Usage: sudo bash test-on-vds.sh <repo_url> [branch] [target_dir]
# Example: sudo bash test-on-vds.sh https://github.com/sattva2020/N8N-AI-Starter-Kit.git test /opt/n8n-ai-starter-kit

REPO_URL="${1:-https://github.com/sattva2020/N8N-AI-Starter-Kit.git}"
BRANCH="${2:-test}"
TARGET_DIR="${3:-/opt/n8n-ai-starter-kit}"
DRY_RUN=${DRY_RUN:-0}

echo "Deploy test: repo=$REPO_URL branch=$BRANCH target=$TARGET_DIR"

ensure_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[!] Command $1 not found"
    return 1
  fi
  return 0
}

install_prereqs_apt() {
  echo "Installing prerequisites via apt..."
  apt-get update
  apt-get install -y git curl jq ca-certificates gnupg lsb-release
  # Docker installation (official install - Debian/Ubuntu)
  if ! command -v docker >/dev/null 2>&1; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  fi
}

install_prereqs() {
  if command -v apt-get >/dev/null 2>&1; then
    install_prereqs_apt
    return
  fi
  if command -v yum >/dev/null 2>&1; then
    echo "Please install docker and docker-compose manually on this distro (yum detected)." >&2
    return
  fi
  echo "Unsupported distro for automatic install. Ensure git, docker and docker compose are installed." >&2
}

if [ "$DRY_RUN" -ne 1 ]; then
  # Ensure minimal tools
  if ! ensure_cmd git || ! ensure_cmd curl; then
    echo "Attempting to auto-install prerequisites..."
    install_prereqs
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN - exiting" && exit 0
fi

# Clone or update
if [ -d "$TARGET_DIR/.git" ]; then
  echo "Target exists, fetching latest..."
  cd "$TARGET_DIR"
  git fetch --all --prune
  git checkout "$BRANCH" || git checkout -b "$BRANCH" origin/$BRANCH || true
  git reset --hard origin/$BRANCH || true
  git clean -fdx || true
else
  echo "Cloning $REPO_URL -> $TARGET_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
  cd "$TARGET_DIR"
fi

# Optional env generation
if [ -x ./scripts/setup.sh ]; then
  echo "Running setup.sh --generate-only to create .env from template (if supported)"
  ./scripts/setup.sh --generate-only || echo "setup.sh --generate-only exited non-zero; proceed manually if needed"
else
  echo "No setup.sh found or not executable; ensure .env exists in repo root or provide one before starting containers."
fi

echo "Starting docker compose stack (detach, build if necessary)"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker compose pull || true
  docker compose up -d --build --remove-orphans
else
  echo "docker compose plugin not found; try 'docker-compose' binary"
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose pull || true
    docker-compose up -d --build --remove-orphans
  else
    echo "No docker compose found. Aborting." >&2
    exit 2
  fi
fi

echo "Waiting for containers to be healthy (30s initial wait)..."
sleep 30

# Basic smoke checks: list running services and check common ports
echo "Docker compose ps:"
docker compose ps || docker-compose ps || true

SMOKE_DIR="/tmp/n8n-ai-starter-kit-test-$(date +%Y%m%d%H%M%S)"
mkdir -p "$SMOKE_DIR"

echo "Collecting container logs (first 200 lines each) into $SMOKE_DIR/logs"
mkdir -p "$SMOKE_DIR/logs"
for cid in $(docker ps -q); do
  name=$(docker inspect --format='{{.Name}}' "$cid" | sed 's#/##')
  docker logs --tail 200 "$cid" > "$SMOKE_DIR/logs/$name.log" 2>&1 || true
done

echo "Running HTTP checks against services listed in docker-compose (best-effort)..."
# User can set HEALTH_CHECKS env var as comma-separated list of http://host:port/path
IFS=',' read -r -a CHECKS <<< "${HEALTH_CHECKS:-http://localhost:11434/}" || true
for url in "${CHECKS[@]}"; do
  echo -n "Checking $url ... "
  if curl -fsS --max-time 10 "$url" >/dev/null 2>&1; then
    echo "OK"
  else
    echo "FAIL (see logs)"
  fi
done

echo "Smoke test finished. Artifacts saved to $SMOKE_DIR"
echo "If everything looks OK, inspect logs and proceed with functional tests or clean up with: docker compose down -v"

exit 0
