#!/usr/bin/env bash
set -euo pipefail
REMOTE_DIR="/opt/graphrag"
CONDA_PREFIX="/root/miniconda"
export PATH="${CONDA_PREFIX}/bin:$PATH"
cd "${REMOTE_DIR}"

echo "=== Python (conda run -n graphrag) ==="
conda run -n graphrag --no-capture-output python -c 'import sys; print(sys.version)'

echo "=== numpy import ==="
conda run -n graphrag --no-capture-output python -c 'import numpy as np; print("numpy", np.__version__)' || echo "numpy import failed"

echo "=== faiss import (detailed) ==="
conda run -n graphrag --no-capture-output python - <<'PY'
import sys, traceback
try:
    import faiss
    print('faiss ok:', faiss.__file__)
except Exception as e:
    print('faiss import error:', type(e).__name__, e)
    traceback.print_exc()
    sys.exit(2)
PY

# locate native faiss libs
echo "=== locating libfaiss *.so in env ==="
find "${CONDA_PREFIX}/envs/graphrag" -type f -name "*faiss*.so*" -print || true

# run ldd on any found libfaiss
for f in $(find "${CONDA_PREFIX}/envs/graphrag" -type f -name "*faiss*.so*" -print); do
  echo "--- ldd for $f ---"
  ldd "$f" || true
done

# try importing graphrag package
echo "=== graphrag import (top-level) ==="
conda run -n graphrag --no-capture-output python - <<'PY'
import importlib, sys, traceback
try:
    m = importlib.import_module("graphrag")
    print("graphrag imported", getattr(m, "__file__", None))
except Exception as e:
    print("graphrag import error:", type(e).__name__, e)
    traceback.print_exc()
    sys.exit(3)
PY

echo "=== END diagnostics ==="
