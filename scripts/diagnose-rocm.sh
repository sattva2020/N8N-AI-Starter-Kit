#!/usr/bin/env bash

# ROCm diagnostics collector for AMD GPUs in N8N AI Starter Kit
# Usage:
#   scripts/diagnose-rocm.sh [--output <file>] [--skip-docker] [--skip-container] [--temp-container]
# Notes:
#   - Intended for Linux hosts (ROCm is Linux-only). On other OS, prints a warning and continues.
#   - By default, does NOT pull/run extra images. Use --temp-container to run rocm/rocm-terminal test.

set -euo pipefail
IFS=$'\n\t'

OUT_DIR="logs/diagnostics"
TS="$(date +%Y%m%d_%H%M%S 2>/dev/null || printf 'now')"
OUT_FILE="${OUT_DIR}/rocm-diagnose-${TS}.log"
DOCKER_OK=1
CONTAINER_CHECK=1
TEMP_CONTAINER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUT_FILE="$2"; shift 2;;
    --skip-docker)
      DOCKER_OK=0; shift;;
    --skip-container)
      CONTAINER_CHECK=0; shift;;
    --temp-container)
      TEMP_CONTAINER=1; shift;;
    -h|--help)
      sed -n '1,30p' "$0"; exit 0;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
done

mkdir -p "$(dirname "$OUT_FILE")"

log() { printf '%s\n' "$*" | tee -a "$OUT_FILE"; }
section() { printf '\n==== %s ====\n' "$*" | tee -a "$OUT_FILE"; }
run() {
  local desc="$1"; shift
  section "$desc"
  # shellcheck disable=SC2145
  echo "+ $@" | tee -a "$OUT_FILE"
  { "$@" 2>&1 || true; } | tee -a "$OUT_FILE"
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

get_compose_cmd() {
  if cmd_exists docker && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif cmd_exists docker-compose; then
    echo "docker-compose"
  else
    echo "" # none
  fi
}

section "ROCm diagnostics start"
log "Output: $OUT_FILE"

section "Host information"
{ uname -a || true; } | tee -a "$OUT_FILE"
if [[ -r /etc/os-release ]]; then
  { echo; cat /etc/os-release; } | tee -a "$OUT_FILE"
fi
{ echo; lsb_release -a; } 2>/dev/null | tee -a "$OUT_FILE" || true

OS_NAME=$(uname -s || echo unknown)
if [[ "$OS_NAME" != "Linux" ]]; then
  log "WARNING: ROCm официально поддерживается только на Linux. Текущая ОС: $OS_NAME"
fi

section "Kernel modules and devices (AMD)"
run "PCI devices (AMD/ATI)" bash -lc "lspci -nn | grep -E 'AMD|ATI' || true"
run "Kernel module amdgpu" bash -lc "lsmod | grep -E '^amdgpu' || echo 'amdgpu module not loaded'"
run "/dev devices" bash -lc "ls -l /dev/kfd /dev/dri 2>/dev/null || echo 'Some devices missing'"
run "User groups" bash -lc "id; echo; groups || true"
run "dmesg amdgpu tail" bash -lc "dmesg -T | grep -i amdgpu | tail -n 200 || true"

section "ROCm tools"
run "rocminfo" bash -lc "rocminfo || true"
run "rocm-smi" bash -lc "rocm-smi || true"

if (( DOCKER_OK )); then
  section "Docker environment"
  run "docker version" docker --version
  run "docker info (rootless?)" bash -lc "docker info 2>/dev/null | grep -i rootless || docker info || true"
  COMPOSE_CMD=$(get_compose_cmd)
  if [[ -n "$COMPOSE_CMD" ]]; then
    run "$COMPOSE_CMD version" bash -lc "$COMPOSE_CMD version || true"
    run "compose config (grep amd-gpu)" bash -lc "$COMPOSE_CMD config 2>/dev/null | grep -n 'amd-gpu\|gpu-amd.override.yml' || $COMPOSE_CMD config || true"
    run "docker ps (running containers)" bash -lc "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"
  else
    log "docker compose/docker-compose не найден"
  fi

  if (( CONTAINER_CHECK )); then
    section "Container checks (if running)"
    for svc in ollama-gpu rstar-vllm-gpu lightrag-gpu; do
      if docker ps --format '{{.Names}}' | grep -q "${svc}$"; then
        run "${svc}: env + devices" bash -lc "docker exec -i ${svc} bash -lc 'printenv | egrep \"HIP|ROCM|CUDA|GPU_TYPE\" || true; echo; ls -l /dev/kfd /dev/dri || true; echo; id'"
      else
        log "skip ${svc}: not running"
      fi
    done
  fi

  if (( TEMP_CONTAINER )); then
    section "Temporary ROCm container test (rocminfo or rocm-smi)"
    run "docker run rocm/rocm-terminal" bash -lc "docker run --rm --device=/dev/kfd --device=/dev/dri -v /dev/dri:/dev/dri rocm/rocm-terminal:latest bash -lc 'rocminfo || rocm-smi || true'"
  fi
fi

section "Summary"
log "Diagnostics completed. File saved to: $OUT_FILE"

exit 0
