#!/usr/bin/env bash
set -euo pipefail
REMOTE_DIR="/opt/graphrag"
CONDA_PREFIX="/root/miniconda"
export PATH="${CONDA_PREFIX}/bin:$PATH"
cd "${REMOTE_DIR}"

LOG=/tmp/remote_test.strace
ERRLOG=/tmp/remote_test.err

echo "Running test under strace (output -> ${LOG})"
# Run under conda env using conda run so activation is non-interactive
conda run -n graphrag --no-capture-output strace -f -s 2000 -o "${LOG}" python3 "${REMOTE_DIR}/test_graphrag_with_ollama.py" 2>"${ERRLOG}" || echo "python exited with $?"

echo "=== DMESG (last 50) ==="
dmesg | tail -n 50 || true

echo "=== STDERR ==="
cat "${ERRLOG}" || true

echo "=== STRACE PREVIEW (first 2000 lines) ==="
head -n 2000 "${LOG}" || true

echo "=== END STRACE ==="
