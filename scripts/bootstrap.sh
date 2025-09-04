#!/usr/bin/env bash
# scripts/bootstrap.sh
# Idempotent bootstrap helper for fresh hosts
# Ensures docker volume traefik_letsencrypt exists and contains /acme.json with 600 perms

set -euo pipefail

VOL_NAME="traefik_letsencrypt"

print() { echo -e "[bootstrap] $*"; }
err() { echo -e "[bootstrap][ERROR] $*" >&2; }

if ! command -v docker >/dev/null 2>&1; then
  err "Docker not found in PATH. Install Docker and retry."
  exit 2
fi

# Create volume if missing
if docker volume ls --format '{{.Name}}' | grep -q "^${VOL_NAME}$"; then
  print "Docker volume ${VOL_NAME} already exists"
else
  print "Creating docker volume ${VOL_NAME}..."
  if docker volume create "${VOL_NAME}" >/dev/null 2>&1; then
    print "Created ${VOL_NAME}"
  else
    err "Failed to create volume ${VOL_NAME}. Check Docker permissions."
    exit 3
  fi
fi

# Ensure acme.json exists and has 600 permissions
print "Ensuring /acme.json exists inside volume and has 600 permissions..."
if docker run --rm -v "${VOL_NAME}:/data" alpine sh -c 'touch /data/acme.json && chmod 600 /data/acme.json' >/dev/null 2>&1; then
  print "/acme.json is present with 600 permissions"
else
  err "Failed to ensure /acme.json inside ${VOL_NAME}. You may need to run this script with elevated Docker privileges."
  exit 4
fi

print "Bootstrap completed. You can now run: docker compose up -d" 
