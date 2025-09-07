#!/usr/bin/env bash
# Safe copy utility
# Usage: safe_copy.sh <local_file> <remote_user@host>:<remote_path> [--yes]
# Optional: set SSH_IDENTITY to the path of the private key to use (e.g. SSH_IDENTITY=~/.ssh/id_rsa_n8n)
# - Shows checksum comparison
# - Shows unified diff (if remote file exists)
# - Creates remote backup before overwrite
# - Requires explicit --yes to perform overwrite

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <local_file> <remote_user@host>:<remote_path> [--yes]"
  exit 2
fi

LOCAL_FILE="$1"
REMOTE_SPEC="$2"
FORCE=false
if [ "${3:-}" = "--yes" ]; then
  FORCE=true
fi

if [ ! -f "$LOCAL_FILE" ]; then
  echo "Local file not found: $LOCAL_FILE" >&2
  exit 3
fi

# compute local checksum (sha256)
if command -v sha256sum >/dev/null 2>&1; then
  LOCAL_CHKSUM=$(sha256sum "$LOCAL_FILE" | awk '{print $1}')
else
  LOCAL_CHKSUM=$(python3 -c "import sys,hashlib; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())" "$LOCAL_FILE")
fi

echo "Local sha256: $LOCAL_CHKSUM"

# parse remote spec
REMOTE_USER_HOST="${REMOTE_SPEC%%:*}"
REMOTE_PATH="${REMOTE_SPEC#*:}"

# support explicit SSH identity via SSH_IDENTITY env var
SSH_IDENTITY="${SSH_IDENTITY:-}"
RUN_SSH() {
  if [ -n "$SSH_IDENTITY" ]; then
    ssh -i "$SSH_IDENTITY" "$@"
  else
    ssh "$@"
  fi
}
RUN_SCP() {
  if [ -n "$SSH_IDENTITY" ]; then
    scp -i "$SSH_IDENTITY" "$@"
  else
    scp "$@"
  fi
}

# function to run remote command
run_remote() {
  RUN_SSH "$REMOTE_USER_HOST" "$1"
}

# check if remote file exists and get checksum
REMOTE_EXISTS=false
REMOTE_CHKSUM=""
  if RUN_SSH "$REMOTE_USER_HOST" "test -f '$REMOTE_PATH' && echo exists" 2>/dev/null | grep -q exists; then
  REMOTE_EXISTS=true
  # try sha256sum on remote
  if RUN_SSH "$REMOTE_USER_HOST" "command -v sha256sum >/dev/null 2>&1 && sha256sum '$REMOTE_PATH' || true" | grep -E '^[0-9a-f]{64}' >/dev/null 2>&1; then
    REMOTE_CHKSUM=$(RUN_SSH "$REMOTE_USER_HOST" "sha256sum '$REMOTE_PATH'" | awk '{print $1}')
  else
    # fallback to python
  REMOTE_CHKSUM=$(RUN_SSH "$REMOTE_USER_HOST" "python3 -c \"import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())\" '$REMOTE_PATH'" )
  fi
  echo "Remote sha256: $REMOTE_CHKSUM"
else
  echo "Remote file does not exist: $REMOTE_USER_HOST:$REMOTE_PATH"
fi

if [ "$REMOTE_EXISTS" = true ] && [ "$LOCAL_CHKSUM" = "$REMOTE_CHKSUM" ]; then
  echo "Files are identical; nothing to do."
  exit 0
fi

# if remote exists, fetch it to a temp file and show diff
if [ "$REMOTE_EXISTS" = true ]; then
  TMP_REMOTE=$(mktemp)
  RUN_SSH "$REMOTE_USER_HOST" "cat '$REMOTE_PATH'" > "$TMP_REMOTE"
  echo "--- unified diff (remote -> local) ---"
  if command -v diff >/dev/null 2>&1; then
    diff -u "$TMP_REMOTE" "$LOCAL_FILE" || true
  else
    echo "diff not available locally; skipping" >&2
  fi
  rm -f "$TMP_REMOTE"
fi

if [ "$FORCE" = false ]; then
  echo "To overwrite remote file, re-run with --yes"
  exit 4
fi

# create remote backup
TS=$(date +%s)
REMOTE_BAK="${REMOTE_PATH}.bak.${TS}"
  RUN_SSH "$REMOTE_USER_HOST" "mkdir -p \"$(dirname \"$REMOTE_PATH\")\" && cp -a '$REMOTE_PATH' '$REMOTE_BAK' 2>/dev/null || true"

echo "Remote backup created (if existed): $REMOTE_USER_HOST:$REMOTE_BAK"

# copy file
RUN_SCP "$LOCAL_FILE" "$REMOTE_USER_HOST:$REMOTE_PATH"

# verify checksum after copy
if RUN_SSH "$REMOTE_USER_HOST" "command -v sha256sum >/dev/null 2>&1 && sha256sum '$REMOTE_PATH' || python3 -c \"import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())\" '$REMOTE_PATH'" | grep -E "${LOCAL_CHKSUM}" >/dev/null 2>&1; then
  echo "Copy verified: checksums match"
  exit 0
else
  echo "Verification failed: remote checksum does not match local" >&2
  exit 5
fi
